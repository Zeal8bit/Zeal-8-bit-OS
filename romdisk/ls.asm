; SPDX-FileCopyrightText: 2023-2024 Zeal 8-bit Computer <contact@zeal8bit.com>; Shawn Sijnstra <shawn@sijnstra.com>;
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "zos_sys.asm"
        INCLUDE "strutils_h.asm"

        SECTION TEXT

        DEFC FILENAME_SIZE = FILENAME_LEN_MAX

        MACRO ERR_CHECK goto_label
                or a
                jp nz, goto_label
        ENDM

        ; Routine to parse the options given in the command line
        EXTERN get_options
        EXTERN error_print
        EXTERN open_error

        ; A static buffer that can be used across the commands implementation
        EXTERN init_static_buffer
        EXTERN init_static_buffer_end
        DEFC INIT_BUFFER_SIZE = init_static_buffer_end - init_static_buffer

        DEFC STATIC_STAT_BUFFER = init_static_buffer
        DEFC STATIC_STRING_BUFFER = init_static_buffer + ZOS_STAT_SIZE

        ; "ls" command main function
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        PUBLIC ls_main
ls_main:
        ; Reset the parameters
        xor a
        ld (given_params), a
        ; Check that argc is 1 or 2 (command itself is part of argc)
        or c
        cp 3
        jp nc, _ls_usage
        dec a ; No parameters is okay
        jp z, _ls_no_option
        ; We have one parameter
        ld de, valid_params
        call get_options
        ERR_CHECK(_ls_usage)
        ; Here C contains the bitmap of given options
        ; Save it to a RMA location to retrieve it later
        ld a, c
        ld (given_params), a
_ls_no_option:
        ld de, cur_path
        OPENDIR()
        or a
        ; In this case, A is negative if an error occurred
        jp m, open_error
        ; Read the directory until there is no more entries
        ld h, a
_ls_next_entry:
        ld de, dir_entry_struct
        ; Parameters:
        ;       H - Opendir dev
        ;       DE - Destination buffer
        READDIR()
        ; If we have no more entries, print a newline and return
        cp ERR_NO_MORE_ENTRIES
        jp z, newline_ret
        ; Else, check for another potential error
        ERR_CHECK(readdir_error)
        ; No error so far, we can print the current entry name
        push hl ; Save HL as it contains the opendir value
        inc de
        ; Prepare parameter
        ld bc, FILENAME_SIZE
        ; If '-l' was given (bit 0 set), we have to given all the details about the file
        ld a, (given_params)
        rrca
        jr c, _ls_detailed
        ; In the case of -1 or no option, replace all the null chars by a space
        call _ls_replace_nulls
        ld bc, FILENAME_SIZE
        ; If '-1' was given, add \n at the end of the string
        ld a, (given_params)
        rrca
        rrca
        jr nc, _ls_no_newline
        ; HL points to the final character (extra char)
        ld (hl), '\n'
        inc bc  ; Include the final \n to the string to print
_ls_no_newline:
        ld de, dir_entry_struct + 1
        S_WRITE1(DEV_STDOUT)
        pop hl
        jp _ls_next_entry
        ; Parameters:
        ;   DE - Address of the string
        ;   BC - Maximum size
        ; Returns:
        ;   HL - DE + BC
        ; Alters:
        ;   A, HL, DE, BC
_ls_replace_nulls:
        ex de, hl
        xor a
        cpir
        ; If not zero, BC is now 0, so not found
        ret nz
        ; Replace the rest with space
        dec hl
        ld (hl), ' '
        ld d, h
        ld e, l
        inc de
        ; BC has already been decremented in CPIR
        ld a, b
        or c
        ret z
        ldir
        ex de, hl
        ret
_ls_detailed:
        ; We arrive here when -l was given
        ; BC contains the maximum file name size
        ; DE contains the filename (string)
        ; Add a NULL-byte at the end of the string
        ld h, d
        ld l, e
        add hl, bc
        ld (hl), 0
        ; Get the stats of the file
        ; BC - Path to file
        ; DE - File info structure, init static buffer in our case
        ld b, d
        ld c, e
        ld de, STATIC_STAT_BUFFER
        STAT()
        or a
        jp nz, _ls_stat_failed
        ; No error, extract the data to show on screen, here is the format:
        ; Filename, size, yyyy-mm-dd hh:mm:ss
        ; We will save this in the init_static_buffer, after stat structure of course
        push bc
        ; Clean the string first with spaces, let's say we will use at most 64 bytes
        ld bc, 63
        ld hl, STATIC_STRING_BUFFER
        ld de, STATIC_STRING_BUFFER + 1
        ld (hl), 0
        ldir
        ; Write the name to the buffer now
        ld de, STATIC_STRING_BUFFER
        ; Pop the file name out of the stack
        pop hl
        call strcpy_raw
        ; Check if it's a dir, if yes, add `/`
        ld hl, STATIC_STAT_BUFFER
        ex de, hl
        ; DE = Stat structure address
        ; HL = String to fill
        ld a, (de)
        inc de
        and 1
        cp D_ISFILE
        jr z, _ls_is_file
        ld (hl), '/'
_ls_is_file:
        ; Now convert the size into a hex value
        ld hl, STATIC_STRING_BUFFER + FILENAME_LEN_MAX + 1 ; give some space after filename
        ld (hl), ' '
        inc hl
        ld (hl), ' '
        inc hl
        ex de, hl
        ; FIXME: Print decimal value?
        ld a,(given_params)
        bit 2,a
        jr nz,_ls_use_hex
        call dword_to_ascii_dec
        jp _ls_decimal_done
_ls_use_hex:
        ld a, '$'       ; Hex value only at the moment
        ld (de), a
        inc de
        call dword_to_ascii
_ls_decimal_done:
        ; Finally, format the date to ascii
        ld (de), ' '
        inc de
        call date_to_ascii
        ; New line to terminate it
        ld (de), '\n'
        inc de
        ; Now we can print DE, however, we have to calculate its length first
        ex de, hl
        ld de, STATIC_STRING_BUFFER
        xor a
        sbc hl, de
        ; Put the result in BC before calling WRITE
        ld b, h
        ld c, l
        S_WRITE1(DEV_STDOUT)
        jp _ls_prepare_next
_ls_stat_failed:
        ; Print a message saying that stat encountered an error
        call _ls_stat_error
_ls_prepare_next:
        pop hl  ; Get back the opendir dev
        jp _ls_next_entry
newline_ret:
        ; Close the opened directory
        ; H already contains the opendir entry
        CLOSE()
        ; If any parameter except h on its own was given, we have already printed a new line,
        ; no need to add one.
        ld a, (given_params)
        and 3
        ; Set A to 0 (success) without modifying the flags
        ret nz
        S_WRITE3(DEV_STDOUT, newline, 1)
        xor a
        ret

        ; Routine to add \n at the end of a file name
        ; Parameters:
        ;       DE - String to concatenate \n to
        ;       BC - FILENAME_SIZE
        ; Returns:
        ;       BC - Length of the new string
        ; Alters:
        ;       A, HL, BC
ls_concat_newline:
        ld h, d
        ld l, e
        xor a
        push bc
        cpir
        ; If BC is 0, we haven't found any \0, we add it now as we have one
        ; spare byte
        ld a, b
        or c
        jr z, _ls_concat_not_found
        ; HL points to the character after \0, decrement it
        dec hl
        ld (hl), '\n'
        pop hl
        ; Carry is 0 here
        sbc hl, bc
        ld b, h
        ld c, l
        ret
_ls_concat_not_found:
        ; HL points after the last char of the string
        ld (hl), '\n'
        pop bc
        inc c
        ret

        ; TODO: Put these generic error routine in a common place
_ls_stat_error:
        ld de, str_stat
        ld bc, str_stat_end - str_stat
        call error_print
        ld a, 1
        ret
str_stat: DEFM "stat error: "
str_stat_end:

_ls_usage:
        S_WRITE3(DEV_STDOUT, str_usage, str_usage_end - str_usage)
        ld a, 1
        ret
str_usage: DEFM "usage: ls <-options>\n"
           DEFM " l - list details\n"
           DEFM " 1 - 1 entry per line\n"
           DEFM " x - hex output\n"
str_usage_end:

readdir_error:
        ld de, str_rddir_err
        ld bc, str_rddir_err_end - str_rddir_err
        call error_print
        ld a, 1
        ret
str_rddir_err: DEFM "readdir error: "
str_rddir_err_end:


        SECTION DATA
cur_path: DEFM ".", 0   ; This is a string, it needs to be NULL-terminated
newline: DEFM "\n"      ; This isn't a proper string, it'll be used with WRITE
     ; Given it one more byte to add a '\n' or '\0'
dir_entry_struct: DEFS ZOS_DIR_ENTRY_SIZE + 1
valid_params: DEFM "l1x", 0
given_params: DEFS 1
