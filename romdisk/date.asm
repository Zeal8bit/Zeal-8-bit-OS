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
        DEFC TIME_OFFSET_IN_STRUCT = 5

        ; Date main routine, print the current date and time on screen.
        ; With zero arguments, just print date.
        ; With one argument, set date; with two arguments, set date and time.
        ; Date and time format is:
        ;       YYYY-MM-DD HH:MM:SS
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC, < 256
        ; Returns:
        ;       A - 0 on success
        PUBLIC date_main
date_main:
        ; Read the existing date whether we are showing or setting.
        ; If we are setting just the date, we need to load current time
        ; so that we don't reset it.
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
        dec c ; Discount command name
        or c
        jr z, _date_main_print ; no args, print
        inc hl ; Skip command name
        inc hl
        ; Parse date
        ld e, (hl) ; Load date string into DE
        inc hl
        ld d, (hl)
        inc hl
        push hl ; Remember current argv and argc
        push bc ;
        ld hl, STATIC_DATE_BUFFER
        call ascii_to_date
        pop bc ; Recall argv and argc
        pop hl
        or a
        jr nz, _date_usage_error
        ; See if there is also a time
        dec c
        or c
        jr z, _do_setdate_syscall
        ; Parse time
        ld e, (hl) ; Load time string into  DE
        inc hl
        ld d, (hl)
        ld hl, STATIC_DATE_BUFFER + TIME_OFFSET_IN_STRUCT
        call ascii_to_time
        or a
        jr nz, _date_usage_error
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
_date_usage_error:
        ld de, date_usage_str
        ld bc, date_usage_str_end - date_usage_str
        S_WRITE1(DEV_STDOUT)
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
        ;       A - nonzero if bad format detected. 
        ;       If A is zero the date parts of the input struct have been filled out.
        ;       DE - DE + 10
        ; Modifies: HL, BC
        PUBLIC ascii_to_date
ascii_to_date:
        xor a
        ld b, '-'
        call read_bcd_pair
        call read_bcd_pair
        call check_char
        call read_bcd_pair
        call check_char
        call read_bcd_pair
        ; TODO calculate and fill out day-of-week
        ret

        ; Read ACSII time and fill out time part of of DATE_STRUCT.
        ; The input format will be as follows:
        ;   HH:MM:SS
        ; Does not check the ':' chars, they can be anything. Does not
        ; validate number ranges.
        ; Parameters:
        ;       HL - Pointer to the time part of date structure
        ;       DE - String source.
        ; Returns:
        ;       A  - nonzero if bad format detected
        ;       The time parts of the input date struct have been filled out.
        ; Modifies: BC
        PUBLIC ascii_to_time
ascii_to_time:
        xor a
        ld b, ':'
        call read_bcd_pair
        call check_char
        call read_bcd_pair
        call check_char
        call read_bcd_pair
        ret

        ; Convert an decimal ascii pair of bytes to a BCD byte.
        ; Parameters
        ;       DE - Pointer to first (high) ascii byte
        ;       HL - Pointer to result byte to update
        ; Returns:
        ;       (HL) - 2 BCD nibbles, big endian
        ;       HL   - HL + 1
        ;       DE   - DE + 2
        ;       A    - unmodified if both input chars are digit,
        ;              nonzero otherwise
read_bcd_pair:
        ld c, a ; we use C as accumulated error condition
        ld a, (de)
        cp '9' + 1
        jr c, _ok1
        ld c, 1
_ok1:   sub '0'
        jr nc, _ok2
        ld c,1
_ok2:   ld (hl),a
        inc de ; next digit
        ld a, (de)
        cp '9' + 1
        jr c, _ok3
        ld c,1
_ok3:   sub '0'
        jr nc, _ok4
        ld c,1
_ok4:   rld
        inc de
        inc hl
        ld a, c ; return original value or 1 if erro detected
        ret

check_char:
        ; Check that char matches expected one.
        ; Parameters
        ;       B  - expected char
        ;       DE - Pointer to char to check
        ; Returns:
        ;       A  - nonzero on mismatch, unmodified on match
        ;       DE - DE + 1
        ; Modifies: C
        ld c, a
        ld a, (de)
        sub b
        or c ; take into account if we started with nonzero in a
        inc de
        ret

date_error:
        ; Nothing special to print before the error message
        ld de, date_usage_str
        jp error_print

date_usage_str:
        DEFM "usage: date [YYYY-MM-DD [HH:MM:SS]]\n"
date_usage_str_end:
        DEFM 0
