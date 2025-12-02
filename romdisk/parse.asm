; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "zos_sys.asm"
        INCLUDE "strutils_h.asm"

        SECTION TEXT

        ; Commands related

        DEFC SIZE_COMMAND_ENTRY = 16
        DEFC ENTRYPOINT_SIZE    = 2
        DEFC MAX_COMMAND_NAME   = (SIZE_COMMAND_ENTRY - ENTRYPOINT_SIZE)
        DEFC MAX_COMMAND_ARGV   = 16
        MACRO NEW_COMMAND name, entrypoint
            EXTERN entrypoint
            DEFS MAX_COMMAND_NAME, name
            DEFW entrypoint
        ENDM

        EXTERN error_print
        EXTERN init_static_buffer
        EXTERN exec_main_bc_de
        EXTERN exec_main_ret_success
        EXTERN try_exec_bc_de
        EXTERN cd_main_de

        ; Parse and execute the command line passed as a parameter.
        ; Parameters:
        ;       DE - Command line
        ;       BC - Length of the command line
        ; Returns:
        ;       None
        ; Alters:
        ;       Any
        PUBLIC parse_exec_cmd
parse_exec_cmd:
        ex de, hl
        ; Check if command is empty
        ld a, (hl)
        or a
        ret z
        ; Trim the leading spaces (if any)
        ld a, ' '
        cp (hl)
        call z, strltrim
        ; If the remaining length is 0, return directly
        ld a, b
        or c
        ret z
        ; TODO: RTRIM
        ; Store the command in the 1-command history
        ; call save_command_in_history
        ; Find the first space, put a \0 instead
        ; and get a pointer to the next string (DE)
        ld a, ' '
        ; memsep will return the length of the remaining string,
        ; in case we need the current length, save it
        push bc
        call memsep
        push af
        ; Check if the first characters are ./, which are special
        ld a, (hl)
        cp '.'
        jr z, _parse_exec_cmd_dot
        pop af
        ; Save the length of the string for prepare_argv_argc
        ; DE contains the address of the next string (token + 1)
        push bc
        ; HL now points to the command name, look for it!
        ; get_command_entry_point returns in IX the entry point of the
        ; command.
        ; A is 0 if no command was found, HL is not altered
        push de
        call get_command_entry_point
        pop de
        pop bc
        or a
        jr z, _process_command_not_found
        ; Prepare the argv (HL) and argc (BC)
        call prepare_argv_argc
        or a    ; A is not 0 if an error occurred
        jr nz, _process_command_argument_error
        ; Clean the stack
        inc sp
        inc sp
        ; Tail call, for systems commands, no need to have a trampoline,
        ; these functions do nothing special
        jp (ix)
_process_command_argument_error:
        pop bc  ; Clean the stack
        S_WRITE3(DEV_STDOUT, err_msg_parameter, err_msg_parameter_end - err_msg_parameter)
        ret


        ; Jump to this routine if the command starts with a '.'
        ; It will interpret the given command as a relative path to the program to execute
        ; Parameters:
        ;   HL - Command string
        ;   DE - Parameter address
        ;   BC - Length of the remaining string
        ;   [SP]   - AF, A 0 if parameter given, must be popped
        ;   [SP+2] - Length of the original string, must be popped
_parse_exec_cmd_dot:
        pop af
        or a
        ; If A is not 0, there was no parameter provided, set DE to 0
        jr z, _parse_exec_cmd_dot_has_param
        ld de, 0
_parse_exec_cmd_dot_has_param:
        ; Clean the stack from the "original length"
        pop bc
        ; Try to execute the binary in HL, with the parameter in DE
        ld b, h
        ld c, l
        jp exec_main_bc_de


        ; Jump to this label if the command was not found.
        ; In that case, check if the given command is an absolute path. If not, check if the default driver (A:/),
        ; which acts as the PATH, contains such binary.
        ; Parameters:
        ;   HL   - String containing the command name
        ;   DE   - Parameter address
        ;   BC   - Length of the remaining string (parameters)
        ;   [SP] - Whole command length, including parameters, must be popped
_process_command_not_found:
        ; If DE points to a \0, there is no parameter, store a NULL instead
        ld a, (de)
        or a
        jr nz, _process_command_has_param
        ld d, a
        ld e, a
_process_command_has_param:
        push de
        ; Check if the command is already an absolute path
        ld d, h
        ld e, l
        inc de
        ld a, (de)
        cp ':'
        jr nz, _process_command_not_path
        inc de
        ld a, (de)
        ; Check if a driver letter was given alone
        or a
        jr z, _process_command_change_disk
        cp '/'
        jr nz, _process_command_not_path
        ; Allow 'A:/' as a way to switch disk
        inc de
        ld a, (de)
        or a
        jr z, _process_command_change_disk_slash_ready
        ; HL is an absolute path, clean the stack and try to execute it
        pop de
        jp _parse_exec_cmd_dot_has_param
_process_command_not_path:
        ; Keep the original command name
        push hl
        ; Try to execute x:/command_name, where x is the default disk
        ex de, hl
        KERNEL_CONFIG(hl)
        ; Structure can be browsed with `inc l`
        inc l
        inc l
        ld a, (hl)
        ; Default disk letter in register A
        ld hl, init_static_buffer
        ld (hl), a
        inc hl
        ld (hl), ':'
        inc hl
        ld (hl), '/'
        inc hl
        ex de, hl
        call strcpy
        ; Get the parameters back from [SP + 2] and put them in DE
        pop hl
        ; Keep the original command name on the stack
        ex (sp), hl
        ex de, hl
        ; Do not alter the parameters (string) length
        push bc
        ld bc, init_static_buffer
        ; Execute program whose name is pointed by BC
        call exec_main_bc_de
        ; Pop the original command name and command length
        pop bc
        pop hl
        ; Pop the whole command length from the stack
        pop hl
        ret


        ; Reach this branch if a disk letter was given `A:`, `B:`, etc...
        ; Change the current directory if no parameter was given
        ; Parameters:
        ;       DE   - Points to the \0 character right after `:`
        ;       HL   - String containing the command name
        ;       BC   - Length of the remaining string (parameters)
        ;       [SP] - Parameters address
        ;       [SP + 2] - Whole command length, including parameters, must be popped
_process_command_change_disk:
        ; Patch the path to add the leading '/' and \0
        ld a, '/'
        ld (de), a
        ; Make the assumption that we will always have space in the buffer (no parameters anyway)
        inc de
        xor a
        ld (de), a
_process_command_change_disk_slash_ready:
        ; Put the directory path in DE as required by `cd_main_de`
        ex de, hl
        pop hl
        ld a, h
        or l
        jr nz, _process_command_not_found_error_de
        ; Change the current directory! (clean the stack)
        pop bc
        jp cd_main_de

        ; Print the command and an error saying we haven't found this command
        ; Parameters:
        ;       HL   - String containing the command name
        ;       BC   - Length of the remaining string (parameters)
        ;       [SP] - Whole command length, including parameters, must be popped
_process_command_not_found_error:
        ; Retrieve the length of the whole command line from the stack, only get
        ; the length of the command name
        ex de, hl ; name in DE
_process_command_not_found_error_de:
        pop hl    ; whole command length
        or a
        sbc hl, bc
        ; Put the length in BC
        ld b, h
        ld c, l
        S_WRITE1(DEV_STDOUT)
        S_WRITE3(DEV_STDOUT, err_msg_not_found, err_msg_not_found_end - err_msg_not_found)
        ret


        ; Look for the command passed in HL in the command list and return
        ; the entry point of it.
        ; Parameters:
        ;       HL - Address of the command (string)
        ; Returns:
        ;       A - 0 if the command was not found, positive value else
        ;       IX - Entry point of the command
        ; Alters:
        ;       A, BC, DE
get_command_entry_point:
        ; Perform a binary search
        ld de, hl       ; DE shall not be changed
        ld bc, system_commands_begin
        ld a, (system_commands_count)
        dec a
        ld ixh, a
        ld ixl, 0
_get_command_entry_point_loop:
        ; Check that the search is not finished, e.g.:
        ; begin > end <==> ixl > ixh <==> ixh - ixl < 0
        ld a, ixh
        sub ixl
        jr c, _get_command_entry_point_not_found

        ; Find the middle index from IXh and IXl
        ld a, ixh
        add ixl
        srl a
        ; Store the middle in IYl
        ld iyl, a
        ld h, 0
        ld l, a
        ; HL = a * 16 (sizeof(comment_entry))
        add hl, hl
        add hl, hl
        add hl, hl
        add hl, hl
        ; HL = &system_commands_begin[a/2]
        add hl, bc
        call strcmp
        or a
        jp z, _get_command_entry_point_found
        jp p, _get_command_entry_point_right

        ; Search left of the array, set IXh to middle (IYl) - 1 while IXl is unchanged
        ld a, iyl
        or a
        ; If A is 0, entry not found
        jp z, _get_command_entry_point_not_found
        dec a
        ld ixh, a

        jr _get_command_entry_point_loop
_get_command_entry_point_right:
        ; Search right of the array, set IXl to middle (IYl) + 1 while IXh is unchanged
        ld a, iyl
        inc a
        ; Detect overflow here, if a is 0, it used to be 255, entry not found
        jr z, _get_command_entry_point_not_found
        ld ixl, a

        jr _get_command_entry_point_loop
_get_command_entry_point_found:
        ld a, MAX_COMMAND_NAME ; indexof(entrypoint) in command_entry structure
        ld b, 0
        ld c, a
        add hl, bc
        ; Load the 16-bit address from HL, put it in BC
        ; before copying it to IX
        ld c, (hl)
        inc hl
        ld b, (hl)
        ld ix, bc
        ex de, hl
        ret
_get_command_entry_point_not_found:
        xor a
        ld ix, 0
        ex de, hl
        ret


        ; Put in the global array command_argv the parameters that shall be
        ; passed to the command invoked.
        ; Parameters:
        ;       HL - Address of the beginning of the string (name of the command itself)
        ;       DE - Address of the first parameter
        ;       BC - (Unused) Length of the whole string
        ; Returns:
        ;       HL - Address of command_argv (**argv)
        ;       BC - Number of entries in command_argv (argc)
        ; Alters:
        ;       HL, DE, BC, A
prepare_argv_argc:
        ld (command_argv), hl ; argv[0] = command name
        ld a, 1
        ld (command_argc), a ; Update argc
        ; Trim the following parameter if it has any space
        ex de, hl             ; HL now contains the rest of the parameters
_prepare_argv_argc_loop:
        ld a, ' '
        cp (hl)
        call z, strltrim
        ; Check that we do have more parameters
        ld a, (hl)
        or a
        jr z, _prepare_argv_argc_end
        ; Check if the character is a quote
        ld a, '\''      ;accept single quote as a string
        cp (hl)
        jp z, _prepare_argv_argc_quote_start
        ld a, '\"'      ;accept double quote as a string
        cp (hl)
        jr z, _prepare_argv_argc_quote_start
        ld a, '('
        cp (hl)
        jp nz, _prepare_argv_argc_no_quote
_prepare_argv_argc_parenth:
        inc hl
        push hl ;this will end up in DE return value
        dec hl ;so the loop works
        ld e,1 ;this is the count of parentheses depth
_prepare_argv_argc_parenth_lp:
        inc hl
        dec bc
        ld a,b
        or c
        jr z,_prepare_argv_argc_parenth_bad
        ld a,(hl)
        or a        ;should not be terminator
        jr z,_prepare_argv_argc_parenth_bad
        cp '('
        jr nz,_prepare_argv_argc_parenth_not_open
        inc e       ;increase count of open parenth
        jr _prepare_argv_argc_parenth_lp
_prepare_argv_argc_parenth_not_open:
        cp ')'      ;decrease count of open parenth
        jr nz,_prepare_argv_argc_parenth_lp
        dec e
        jr nz,_prepare_argv_argc_parenth_lp
        xor a
        ld (hl),a
        inc a        ;will become 0 for success below
_prepare_argv_argc_parenth_bad: ;assumes a=0 for bad.
        dec a
        inc hl
        dec bc
        ex de,hl
        pop hl
        jr _prepare_argv_argc_quote_process_end

_prepare_argv_argc_quote_start:
        inc hl
        dec bc
        ; Look for the closing quote
        call memsep
_prepare_argv_argc_quote_process_end:
        or a
        jp nz, _prepare_argv_argc_error
        ; Next parameter, in DE, should begin with either ' ' or 0
        ld a, (de)
        or a
        jp z, _prepare_argv_argc_quote
        cp ' '
        jp z, _prepare_argv_argc_quote_unfinished
        jp _prepare_argv_argc_error
_prepare_argv_argc_quote_unfinished:
        ld a, 0xff
_prepare_argv_argc_quote:
        cpl     ; Complement of A to have: 0 is not finished, 0xff is finished
        inc de
        push af
        jp _prepare_argv_argc_save_arg
_prepare_argv_argc_no_quote:
        ld a, ' '
        call memsep
        push af
_prepare_argv_argc_save_arg:
        ; Store this parameter (HL) in our array
        ; Here is how to proceed:
        ; Save DE (next parameters), put the current parameter in DE, load the
        ; address of the parameter (to store it) in HL, store DE in HL and
        ; restore DE then. Once the current parameter is saved, we don't need it
        ; anymore
        push de
        ex de, hl
        ld hl, command_argv
        ld a, (command_argc)    ; Make the assumption that we won't have more than 255 parameters
        ; Update this value now, to save few cycles
        inc a
        ld (command_argc), a
        dec a
        ; End of the update
        add a                   ; A *= 2 as a pointer is 2 bytes
        add a, l
        ld l, a
        ld a, h
        adc a, 0
        ld h, a                 ; 16-bit addition HL = ((H + carry) << 8) | (L + a)
        ld (hl), e              ; 16-bit load, little-endian of course
        inc hl
        ld (hl), d
        ; Restore the previous DE directly in HL, thus, HL contains the rest of
        ; the command
        pop hl
        pop af
        ; If A is not null, we reached the end of the command line
        or a
        jp z, _prepare_argv_argc_loop
_prepare_argv_argc_end:
        ld a, (command_argc)
        ld c, a
        xor a
        ld b, a
        ld hl, command_argv
        ret
_prepare_argv_argc_error:
        ld a, 1
        ret

        ; Save the given command in the history
        ; Parameters:
        ;       HL - Current command
        ;       BC - Current command length
        ; Returns:
        ;       None
        ; Alters:
        ;       A, DE
save_command_in_history:
        ; Start by saving the size of the current command, it won't exceed 255
        ld de, command_prev_size
        ld a, c
        ld (de), a
        ; Proceed with the buffer copy
        push hl
        push bc
        inc bc  ; Include the terminating null byte
        ld de, command_prev
        ldir
        pop bc
        pop hl
        ret

        ; Print all the commands available
        PUBLIC help_main
help_main:
        S_WRITE3(DEV_STDOUT, help_msg, help_msg_end - help_msg)
        ld a, (system_commands_count)
        ld b, a
        ld de, system_commands_begin
        ld hl, DEV_STDOUT
_help_main_loop:
        ; Browse all commands name
        push bc
        ld bc, MAX_COMMAND_NAME
        push de
        WRITE()
        ; Print a newline
        ld bc, 1
        ld de, help_msg_newline
        WRITE()
        pop de
        ex de, hl
        ld bc, SIZE_COMMAND_ENTRY
        add hl, bc
        ex de, hl
        pop bc
        djnz _help_main_loop
        ret

help_msg:
    DEFM "List of commands:"
help_msg_newline:
    DEFM "\n"
help_msg_end:

        SECTION DATA
system_commands_begin:
    IF CONFIG_ENABLE_COREUTILS
        NEW_COMMAND("cd", cd_main)
        NEW_COMMAND("clear", clear_main)
        NEW_COMMAND("date", date_main)
        NEW_COMMAND("exec", exec_main)
        NEW_COMMAND("expr", expr_main)
        NEW_COMMAND("help", help_main)
        NEW_COMMAND("load", load_main)
        NEW_COMMAND("reset", reset_main)
        NEW_COMMAND("sleep", sleep_main)
        NEW_COMMAND("uartrcv", uartrcv_main)
        NEW_COMMAND("uartsnd", uartsnd_main)
    ELSE
        NEW_COMMAND("cat", cat_main)
        NEW_COMMAND("cd", cd_main)
        NEW_COMMAND("clear", clear_main)
        NEW_COMMAND("cp", cp_main)
        NEW_COMMAND("date", date_main)
        NEW_COMMAND("dir", ls_main)
        NEW_COMMAND("echo", echo_main)
        NEW_COMMAND("exec", exec_main)
        NEW_COMMAND("expr", expr_main)
        NEW_COMMAND("help", help_main)
        NEW_COMMAND("hexdump", hexdump_main)
        NEW_COMMAND("less", less_main)
        NEW_COMMAND("load", load_main)
        NEW_COMMAND("ls", ls_main)
        NEW_COMMAND("mkdir", mkdir_main)
        NEW_COMMAND("reset", reset_main)
        NEW_COMMAND("rm", rm_main)
        NEW_COMMAND("sleep", sleep_main)
        NEW_COMMAND("uartrcv", uartrcv_main)
        NEW_COMMAND("uartsnd", uartsnd_main)
        NEW_COMMAND("xfer", xfer_main)
    ENDIF
        ; Commands related to I2C
;        DEFS MAX_COMMAND_NAME, "i2cdetect"
;        DEFW i2cdetect_main
;        DEFS MAX_COMMAND_NAME, "i2cget"
;        DEFW i2cget_main
;        DEFS MAX_COMMAND_NAME, "i2cset"
;        DEFW i2cset_main
system_commands_count: DEFB (system_commands_count - system_commands_begin) / SIZE_COMMAND_ENTRY
        ; Errors
err_msg_not_found: DEFM ": command not found\n"
err_msg_not_found_end:
err_msg_parameter: DEFM "error parsing parameters: could not find matching \'\n"
err_msg_parameter_end:


        SECTION BSS
        ; Arguments related
command_argv:   DEFS MAX_COMMAND_ARGV * 2
command_argc:   DEFS 1
        ; History related
command_prev_size: DEFS 1
command_prev: DEFS PATH_MAX + 1
