; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "zos_sys.asm"

        SECTION TEXT

        EXTERN error_print
        EXTERN date_to_ascii

        ; A static buffer that can be used by any command implementation
        EXTERN init_static_buffer
        DEFC STATIC_DATE_BUFFER = init_static_buffer

        ; Date main routine, print the current date and time on screen.
        ; With zero arguments, just print date.
        ; With one argument, set date; with two arguments, set date and time.
        ; Date and time format is:
        ;       YYYY-MM-DD HH:MM:SS
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        PUBLIC date_main
date_main:
        ; Read the existing date whether we are reading or writing
        ld de, STATIC_DATE_BUFFER
        ; Get system date:
        ;   DE - Address of the date structure to fill. Must be at least DATE_STRUCT_SIZE bytes.
        ; Returns:
        ;   A - ERR_SUCCESS on success, error code else
        push hl
        GETDATE()
        pop hl
        or a
        jp nz, date_error
        dec bc ; Discount command name
        ld a, b ; See if there are any arguments
        or c
        jr z, _date_main_print ; no args, print
        ; Parse date
        inc hl ; Skip command name
        inc hl
        ld e, (hl) ; Load date string into DE
        inc hl
        ld d, (hl)
        inc hl
        push hl
        ld hl, STATIC_DATE_BUFFER
        call ascii_to_date
        ; We could make the parser do some checks and test here
        pop hl
        ; See if there is also a time
        dec bc
        ld a, b
        or c
        jr z, _do_setdate_syscall
        ; Parse time
        ld e, (hl) ; Load time string into  DE
        inc hl
        ld d, (hl)
        ld hl, STATIC_DATE_BUFFER
        call ascii_to_time
        ; We could make the parser do some checks and test here
_do_setdate_syscall:
        ld de, STATIC_DATE_BUFFER
        SETDATE()
        or a
        jp nz, date_error
_date_main_print:
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

        ; Read ACSII date and fill out date part of DATE_STRUCT.
        ; The input format will be as follows:
        ;   YYYY-MM-DD
        ; Does not check the '-' chars, they can be anything. Does not
        ; validate number ranges.
        ; Parameters:
        ;       HL - Pointer to the date structure, of size DATE_STRUCT_SIZE
        ;       DE - String source.
        ; Returns:
        ;       The date parts of the input date struct have been filled out.
        ;       DE - DE + 10
        PUBLIC ascii_to_date
ascii_to_date:
        push hl
        call read_bcd_pair
        call read_bcd_pair
        inc de ; skip '-'
        call read_bcd_pair
        inc de ; skip '-'
        call read_bcd_pair
        ; TODO calculate and fill out day-of-week
        pop hl
        ret

        ; Read ACSII time and fill out time part of of DATE_STRUCT.
        ; The input format will be as follows:
        ;   HH:MM:SS
        ; Does not check the ':' chars, they can be anything. Does not
        ; validate number ranges.
        ; Parameters:
        ;       HL - Pointer to the date structure, of size DATE_STRUCT_SIZE
        ;       DE - String source.
        ; Returns:
        ;       The time parts of the input date struct have been filled out.
        ; Modifies: BC
        PUBLIC ascii_to_time
ascii_to_time:
        push hl
        ld bc, 5
        add hl, bc ; skip year (2 bytes), month, day, day of week
        call read_bcd_pair
        inc de ; skip ':'
        call read_bcd_pair
        inc de ; skip ':'
        call read_bcd_pair
        pop hl
        ret

        ; Convert an decimal ascii pair of bytes to a BCD byte. No checking.
        ; Parameters
        ;       DE - Pointer to first (high) ascii byte
        ;       HL - Pointer to result byte to update
        ; Returns:
        ;       (HL) - 2 BCD nibbles, big endian
        ;       HL   - HL + 1
        ;       DE   - DE + 2
        ; Modifies: A
read_bcd_pair:
        ld a, (de)
        sub '0'
        ld (hl),a
        inc de
        ld a, (de)
        sub '0'
        rld
        inc de
        inc hl
        ret

date_error:
        ; Nothing special to print before the error message
        ld de, 0
        jp error_print
