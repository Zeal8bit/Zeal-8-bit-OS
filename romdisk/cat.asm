; SPDX-FileCopyrightText: 2024 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "zos_sys.asm"

        SECTION TEXT

        DEFC FILENAME_SIZE = 16

        MACRO ERR_CHECK goto_label
                or a
                jp nz, goto_label
        ENDM

        EXTERN error_print

        ; A static buffer that can be used across the commands implementation
        EXTERN init_static_buffer
        EXTERN init_static_buffer_end
        DEFC INIT_BUFFER_SIZE = init_static_buffer_end - init_static_buffer

        ; "cat" command main function
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        PUBLIC cat_main
cat_main:
        ; Check that argc is at least 2 (command itself is part of argc)
        ld a, c
        dec a
        jr z, cat_usage
        inc hl
        inc hl  ; skip the first pointer
        ; Number of files in E
        ld e, a
        ; Retrieve all the filenames given as a parameter and print them all
_cat_arg_loop:
        ld c, (hl)
        inc hl
        ld b, (hl)
        inc hl
        push hl
        push de
        call cat_read_file
        pop de
        pop hl
        ; Check if some files are remaining
        dec e
        jr nz, _cat_arg_loop
        ; A contains the last error code (last file)
        ret

cat_usage:
        S_WRITE3(DEV_STDOUT, str_usage, str_usage_end - str_usage)
        ld a, 1
        ret


        ; Open and read the given file
        ; Parameters:
        ;   BC - File name
        ; Alters:
        ;   A, BC, DE, HL
cat_read_file:
        ld h, O_RDONLY
        OPEN()
        or a
        ; In this case, A is negative if an error occurred
        jp m, open_error
        ; Else, open succeed, we can start reading the file
        ld h, a
        ld de, init_static_buffer
        ld bc, INIT_BUFFER_SIZE
_cat_read_loop:
        READ()
        or a
        jp nz, read_error
        ; Check if we've reached the end of the file
        ld a, b
        or c
        jr z, _cat_read_end
        ; Save the file dev (H) on the stack
        push hl
        ; Check if BC is smaller than the buffer size, if this is the case,
        ; we can end the loop after writing to STDOUT.
        push bc
        S_WRITE1(DEV_STDOUT)
        ; if (value_read == INIT_BUFFER_SIZE)
        ;       continue the loop;
        pop hl
        ; 16-bit add doesn't set the Z flag, so let's use sbc instead
        xor a
        ld bc, INIT_BUFFER_SIZE
        sbc hl, bc
        ; Pop doesn't alter flags
        pop hl
        ; H now contains the opened dev, BC is still the buffer size and DE is the buffer
        jr z, _cat_read_loop
        ; End of loop else
_cat_read_end:
        ; Close the opened file (dev in H)
        CLOSE()
        xor a
        ret

open_error:
        ; The error is negated
        neg
        ld de, str_open_err
        ld bc, str_open_err_end - str_open_err
        call error_print
        ld a, 2
        ret

read_error:
        ; We have to close the file dev which is in h, save A as it contains
        ; the real error that occurred
        ld b, a
        CLOSE()
        ; Ignore the potential error from close
        ld a, b
        ld de, str_read_err
        ld bc, str_read_err_end - str_read_err
        call error_print
        ; Return an error in any case
        ld a, 3
        ret


str_usage: DEFM "usage: cat <path_to_file>\n"
str_usage_end:
str_open_err: DEFM "open error: "
str_open_err_end:
str_read_err: DEFM "read error: "
str_read_err_end:
