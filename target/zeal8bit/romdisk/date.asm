; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "syscalls_h.asm"

        SECTION TEXT

        EXTERN error_print
        EXTERN date_to_ascii

        ; A static buffer that can be used by any command implementation
        EXTERN init_static_buffer
        DEFC STATIC_DATE_BUFFER = init_static_buffer

        ; date main routine. 
        ; Print the current date and time on screen
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        PUBLIC date_main
date_main:
        ; Ignore parameters
        ; Get system date:
        ;   DE - Address of the date structure to fill. Must be at least DATE_STRUCT_SIZE bytes.
        ; Returns:
        ;   A - ERR_SUCCESS on success, error code else
        ld de, STATIC_DATE_BUFFER
        GETDATE()
        or a
        jp nz, date_error
        ; Success, we can print the date
        ld hl, STATIC_DATE_BUFFER + 16
        ex de, hl
        ; DE will be modified by the routine, save it first
        push de
        call date_to_ascii
        ; New line character at the end
        ld a, '\n'
        ld (de), a
        pop de
        ; Print DE now on the standard output
        ; DE - Buffer
        ; BC - Size
        ; H  - Descriptor
        ld h, DEV_STDOUT
        ld bc, 20
        WRITE()
        ret

date_error:
        ; Nothing special to print before the error message
        ld de, 0
        jp error_print
