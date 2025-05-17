; SPDX-FileCopyrightText: 2023 Shawn Sijnstra <shawn@sijnstra.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "zos_sys.asm"
        INCLUDE "strutils_h.asm"

        SECTION TEXT

        EXTERN error_print

        MACRO ERR_CHECK goto_label
                or a
                jp nz, goto_label
        ENDM

        ; "sleep" command main function
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        PUBLIC sleep_main
sleep_main:
        ; Check that argc is 2 (command itself is part of argc)
        ld a, c
        cp 2
        jp nz, _sleep_usage
        ; Retrieve the filename given as a parameter
        inc hl
        inc hl  ; skip the first pointer
        ld e,(hl)       ;grab 2nd pointer
        inc hl
        ld c,(hl)
        ex de,hl        ;pointer in HL
        call    parse_int       ;strutils - accepts 16 bit dec or hex input at HL
        or      a               ;0 is ok, 1 is overflow, 2 is bad digit
        jr      nz,_sleep_usage

        ; value was in hl
_sleep_do:
        ex      de,hl
        MSLEEP()
        ERR_CHECK(_sleep_error)
        ret

_sleep_usage:
        S_WRITE3(DEV_STDOUT, str_usage, str_usage_end - str_usage)
        ld a, 1
        ret

_sleep_error:
        ; Give NULL to error_print to have a default error message
        ld de, 0
        call error_print
        ld a, 2
        ret

str_usage: DEFM "usage: sleep <X>\n X=0-65535 or 0xffff msec\n"
str_usage_end:
