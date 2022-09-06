; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "syscalls_h.asm"
        INCLUDE "errors_h.asm"

        SECTION TEXT

        DEFC FILENAME_SIZE = 16

        MACRO ERR_CHECK goto_label
                or a
                jp nz, goto_label
        ENDM

        ; Routine to parse the options given in the command line
        EXTERN get_options
        EXTERN strcpy
        EXTERN error_print

        ; A static buffer that can be used across the commands implementation
        EXTERN init_static_buffer
        EXTERN init_static_buffer_end
        DEFC INIT_BUFFER_SIZE = init_static_buffer_end - init_static_buffer

        DEFC STATIC_STAT_BUFFER = init_static_buffer
        DEFC STATIC_STRING_BUFFER = init_static_buffer + STAT_STRUCT_SIZE

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
        jp nc, _ls_too_many_param
        dec a ; No parameters is okay
        jp z, _ls_no_option
        ; We have one parameter
        ld de, valid_params
        call get_options
        ERR_CHECK(_ls_invalid_param)
        ; Here C contains the bitmap of given options
        ; Save it to a RMA location to retrieve it later
        ld a, c
        ld (given_params), a
_ls_no_option:
        ld de, cur_path
        OPENDIR()
        or a
        ; In this case, A is negative if an error occured
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
        ; If '-1' was given, add \n at the end of the string
        rrca
        call c, ls_concat_newline
        S_WRITE1(DEV_STDOUT)
        pop hl
        jp _ls_next_entry
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
        ld bc, 64
        ld hl, STATIC_STRING_BUFFER
        ld de, STATIC_STRING_BUFFER + 1
        ; FIXME: Use spaces instead of NULL-byte. The video driver will show null-bytes as
        ; spaces but this might not be the case for all the drivers.
        ld (hl), 0
        ldir
        ; Write the name to the buffer now
        ld de, STATIC_STRING_BUFFER
        ; Pop the file name out of the stack
        pop hl
        call strcpy
        ; Now convert the size into a hex value
        ld de, STATIC_STRING_BUFFER + MAX_FILE_NAME + 2 ; give some space after filename
        ld hl, STATIC_STAT_BUFFER
        ; FIXME: Print decimal value?
        ld a, '$'       ; Hex value only at the moment
        ld (de), a
        inc de
        call dword_to_ascii
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
        ; If any parameter was given, we have already printed a new line,
        ; no need to add one.
        ld a, (given_params)
        or a
        ; Set A to 0 (succcess) without modifying the flags
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

_ls_stat_error:
        ld de, str_stat
        ld bc, str_stat_end - str_stat
        call error_print
        ld a, 1
        ret
str_stat: DEFM "stat error: "
str_stat_end:

_ls_invalid_param:
        ld de, str_invalid
        ld bc, str_invalid_end - str_invalid
        call error_print
        ld a, 1
        ret
str_invalid: DEFM "invalid parameter: "
str_invalid_end:

_ls_too_many_param:
        ld de, str_params
        ld bc, str_params_end - str_params
        call error_print
        ld a, 1
        ret
str_params: DEFM "too many parameters: "
str_params_end:

open_error:
        neg
        ld de, str_open_err
        ld bc, str_open_err_end - str_open_err
        call error_print
        ld a, 1
        ret
str_open_err: DEFM "open error: "
str_open_err_end:

readdir_error:
        ld de, str_rddir_err
        ld bc, str_rddir_err_end - str_rddir_err
        call error_print
        ld a, 1
        ret
str_rddir_err: DEFM "readdir error: "
str_rddir_err_end:

    ; TODO: Move the following to another file/lib

        ; Convert a date (DATE_STRUCT) to ASCII.
        ; The format will be as followed:
        ; YYYY-MM-DD HH:MM:SS
        ; Parameters:
        ;       HL - Pointer to the date structure, of size DATE_STRUCT_SIZE
        ;       DE - String destination. It must have at least 19 bytes free
        ; Returns:
        ;       HL - HL + DATE_STRUCT_SIZE
        ;       DE - DE + 19
date_to_ascii:
        push bc
        ld b, h
        ld c, l
        ; HL will be used as a destination
        ex de, hl
        ; Read the year top digits first
        ld a, (bc)
        call _date_to_ascii_digits
        ld a, (bc)
        call _date_to_ascii_digits
        ld (hl), '-'
        inc hl
        ; BC points to the month now
        ld a, (bc)
        call _date_to_ascii_digits
        ld (hl), '-'
        inc hl
        ; BC points to the day now
        ld a, (bc)
        call _date_to_ascii_digits
        ld (hl), ' '
        inc hl
        ; Skip the day name
        inc bc
        ; Hours
        ld a, (bc)
        call _date_to_ascii_digits
        ld (hl), ':'
        inc hl
        ; Minutes
        ld a, (bc)
        call _date_to_ascii_digits
        ld (hl), ':'
        inc hl
        ; Seconds
        ld a, (bc)
        call _date_to_ascii_digits
        ; Restore HL, DE and BC
        ex de, hl
        ld h, b
        ld l, c
        pop bc
        ret
_date_to_ascii_digits:
        call byte_to_ascii
        ld (hl), d
        inc hl
        ld (hl), e
        inc hl
        inc bc
        ret


        ; Convert a 32-bit value to ASCII (hex)
        ; Parameters:
        ;       HL - Pointer to a 32-bit value, little-endian
        ;       DE - String destination. It must have at least 8 free bytes to write the ASCII result.
        ; Returns:
        ;       HL - HL + 4
        ;       DE - DE + 8
        ; Alters:
        ;       A, DE
        PUBLIC dword_to_ascii
dword_to_ascii:
        push bc
        ld c, (hl)      ; Lowest byte
        inc hl
        ld b, (hl)
        inc hl
        push bc
        ld c, (hl)
        inc hl
        ld a, (hl)      ; Highest byte
        inc hl
        ; HL must be returned like this
        ex (sp), hl     ; HL contains lowest byte value now
        push hl
        ; Use HL as the destination, DE will be used as return value of byte_to_ascii
        ex de, hl
        call _dword_to_ascii_convert_store
        ld a, c
        call _dword_to_ascii_convert_store
        pop bc
        ld a, b        
        call _dword_to_ascii_convert_store
        ld a, c
        call _dword_to_ascii_convert_store
        ; Put back the destination (HL) inside DE
        ex de, hl
        pop hl
        pop bc
        ret
_dword_to_ascii_convert_store:
        call byte_to_ascii
        ld (hl), d
        inc hl
        ld (hl), e
        inc hl
        ret

    ; Convert an 8-bit value to ASCII (hex)
    ; Parameters:
    ;       A - Value to convert
    ; Returns:
    ;       D - First character
    ;       E - Second character 
    ; Alters:
    ;       A
    PUBLIC byte_to_ascii
byte_to_ascii:
    ld e, a
    rlca
    rlca
    rlca
    rlca
    and 0xf
    call _byte_to_ascii_nibble
    ld d, a
    ld a, e
    and 0xf
    call _byte_to_ascii_nibble
    ld e, a
    ret

_byte_to_ascii_nibble:
    ; If the byte is between 0 and 9 included, add '0'
    sub 10
    jp nc, _byte_to_ascii_af
    ; Byte is between 0 and 9
    add '0' + 10
    ret
_byte_to_ascii_af:
    ; Byte is between A and F
    add 'A'
    ret



    ; Function copying src string into dest, including the terminating null byte
    ; Parameters:
    ;       HL - src string
    ;       DE - dst string
    ; Alters
    ;       A
    PUBLIC strcpy
strcpy:
    push hl
    push bc
    push de
    ld bc, 0xffff
_strcpy_loop:
    ld a, (hl)
    ; Copy byte into de, even if it's null-byte
    ldi
    ; Test null-byte here
    or a
    jp nz, _strcpy_loop
    pop de
    pop bc
    pop hl
    ret


        SECTION DATA
cur_path: DEFM ".", 0   ; This is a string, it needs to be NULL-terminated
newline: DEFM "\n"      ; This isn't a proper string, it'll be used with WRITE
     ; Given it one more byte to add a '\n' or '\0'
dir_entry_struct: DEFS DISKS_DIR_ENTRY_SIZE + 1
valid_params: DEFM "l1", 0
given_params: DEFS 1
