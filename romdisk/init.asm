; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "zos_sys.asm"
        INCLUDE "zos_video.asm"
        INCLUDE "zos_keyboard.asm"

        DEFC BG_COLOR     = TEXT_COLOR_BLACK
        DEFC CURDIR_COLOR = TEXT_COLOR_LIGHT_GRAY
        DEFC TEXT_COLOR   = TEXT_COLOR_WHITE

        ; Designate the order of the sections before starting the code
        ; We can name the sections whatever we want, but it has to match
        ; across all the files

        ; ---------------- START ----------------;
        SECTION TEXT
        ORG 0x4000
        SECTION DATA
        SECTION BSS
        ; Give a hardcoded address to the BSS section so that it is not put inside the TEXT
        ; binary (and init.bin file is then smaller)
        ; This value should be adapted if the TEXT section grows bigger.
        ORG 0x6000
        ; ----------------  END  ----------------;

        ; Start the actual code
        SECTION TEXT
        DEFC PROMPT_CHAR = '>'

        EXTERN error_print

        MACRO ERR_CHECK goto_label
                or a
                jr nz, goto_label
        ENDM

        EXTERN parse_exec_cmd

next_command:
        ; Set STDIN mode to cooked
        call set_stdin_mode
        ; Set the STDOUT color before printing the directory
        ld e, CURDIR_COLOR
        call set_out_color
        ; Get and print the current directory (keep it in a variable)
        call get_current_dir
        ERR_CHECK(error_current_dir)
        ; Print the current directory
        ld h, DEV_STDOUT
        WRITE()
        ERR_CHECK(error_printing_dir)
        ; Reset the text color
        ld e, TEXT_COLOR
        call set_out_color
        ; Read from the stdin
        ld de, bigbuffer
        ld bc, bigbuffer_end - bigbuffer
        ld h, DEV_STDIN
        READ()
        ERR_CHECK(error_reading_stdin)
        ; The command line size has been put in BC, in theory, BC cannot be 0,
        ; because there is \n at the end in any case. However, let's be safe,
        ; and check for 0 and 1. Remove the final \n too.
        ld a, b
        or c
        jp z, next_command
        ; Check that BC is not 1 and remove the final \n
        dec bc
        ld a, b
        or c
        jp z, next_command
        ld h, d
        ld l, e
        add hl, bc
        ld (hl), 0
        ; We can now parse the command line
        call parse_exec_cmd
        jp next_command


error_current_dir:
        ld de, str_curdir_err
        ld bc, str_curdir_err_end - str_curdir_err
        jr call_err_loop
str_curdir_err:
        DEFM "error getting curdir: "
str_curdir_err_end:

error_printing_dir:
        ld de, str_print_err
        ld bc, str_print_err_end - str_print_err
        jr call_err_loop
str_print_err:
        DEFM "error printing: "
str_print_err_end:

error_reading_stdin:
        ld de, str_rdstdin_err
        ld bc, str_rdstdin_err_end - str_rdstdin_err
call_err_loop:
        call error_print
        jr err_loop
str_rdstdin_err:
        DEFM "error reading input: "
str_rdstdin_err_end:

err_loop:
        halt
        jr $


        ; Set STDIN mode to cooked
set_stdin_mode:
        ld h, DEV_STDIN
        ld c, KB_CMD_SET_MODE
        ld e, KB_MODE_COOKED
        IOCTL()
        or a
        ret z
        ; Error, the target doesn't support RAW mode
        ld de, _set_stdin_err
        ld bc, _set_stdin_err_end - _set_stdin_err
        jr call_err_loop
_set_stdin_err: DEFM "error stdin mode: "
_set_stdin_err_end:


        ; Set the current text color for the standard output
        ; Parameters:
        ;   E - Foreground color to use
set_out_color:
        ld h, DEV_STDOUT
        ld c, CMD_SET_COLORS
        ld d, BG_COLOR
        IOCTL()
        ret


        ; Get the current directory from the kernel, retrieve its size,
        ; append the PROMPT_CHAR and save the new length in curdir_len
        ; Parameters:
        ;       None
        ; Returns:
        ;       DE - Current directory string
        ;       BC - Length of the string
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, BC, DE
get_current_dir:
        ; Get the current directory
        ld de, curdir
        CURDIR()
        or a
        ret nz
        call promptlen
        ld (curdir_len), bc
        xor a   ; Success
        ret

        ; Get the length of the current path and append PROMPT_CHAR to it
        ; Parameters:
        ;       DE - String to get the length of
        ; Returns:
        ;       BC - Size of the string in DE, after appending PROMPT_CHAR
        ; Alters:
        ;       A
promptlen:
        push de
        ex de, hl
        xor a
        ld b, a
        ld c, a
_promptlen_loop:
        cp (hl)
        jp z, _promptlen_loop_end
        inc hl
        inc bc
        jp _promptlen_loop
_promptlen_loop_end:
        ld (hl), PROMPT_CHAR
        inc hl
        ld (hl), a      ; NULL-terminated
        inc bc
        ex de, hl
        pop de
        ret

        SECTION BSS
curdir: DEFS PATH_MAX + 1
curdir_len: DEFS 2
bigbuffer: DEFS 81
bigbuffer_end:
        ; Allocate a few more bytes so that we can append some characters
        DEFS 2

        PUBLIC init_static_buffer
        PUBLIC init_static_buffer_end
init_static_buffer: DEFS 1024
init_static_buffer_end: