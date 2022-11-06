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

        EXTERN error_print

        ; A static buffer that can be used across the commands implementation
        EXTERN init_static_buffer
        EXTERN init_static_buffer_end
        DEFC INIT_BUFFER_SIZE = init_static_buffer_end - init_static_buffer

        ; "less" command main function
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        PUBLIC less_main
less_main:
        ; Check that argc is 2 (command itself is part of argc)
        ld a, c
        cp 2
        jp nz, _less_usage
        ; Retrieve the filename given as a parameter
        inc hl
        inc hl  ; skip the first pointer
        ld c, (hl)
        inc hl
        ld b, (hl)
        ; Filepath in BC now, open the file
        ; BC - Path to file
        ; H - Flags
        ld h, O_RDONLY
        OPEN()
        or a
        ; In this case, A is negative if an error occurred
        jp m, open_error
        ; Else, open succeed, we can start reading the file
        ld h, a
        ld de, init_static_buffer
        ld bc, INIT_BUFFER_SIZE
_less_read_loop:
        READ()
        ; Check for a potential error
        or a
        jp nz, read_error 
        ; Check if we've reached the end of the file
        ld a, b
        or c
        jp z, _less_end
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
        jp z, _less_read_loop
        ; End of loop else
_less_end:
        ; Close the opened file (dev in H)
        CLOSE()
        xor a
        ret

_less_usage:
        S_WRITE3(DEV_STDOUT, str_usage, str_usage_end - str_usage)
        ld a, 1
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
        ; We have to close the file dev which is in h
        CLOSE()
        ld de, str_read_err
        ld bc, str_read_err_end - str_read_err
        call error_print
        ; Return an error in any case
        ld a, 3
        ret


str_usage: DEFM "usage: less <path_to_file>\n"
str_usage_end:
str_open_err: DEFM "error opening the file: "
str_open_err_end:
str_read_err: DEFM "error reading the file: "
str_read_err_end:
