; SPDX-FileCopyrightText: 2023 Shawn Sijnstra <shawn@sijnstra.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "zos_sys.asm"

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
        ld c, (hl)
        inc hl
        ld b, (hl)
        ld      a,(bc)
        sub     '0'
        jr      c,_sleep_usage
        cp      10
        jr      nc,_sleep_usage
        ld      l,a
        ld      h,0
        ld      a,3     ;allow 3 more digits


_sleep_convlp:
        ld      (_sleep_max),a
        inc     bc
        ld      a,(bc)
        cp      ' '+1
        jr      c,_sleep_do
        sub     '0'
        jr      c,_sleep_usage
        cp      10
        jr      nc,_sleep_usage       
        call    _sleep_times10
        ld      e,a
        ld      d,0
        add     hl,de
        ld      a,(_sleep_max)
        dec     a
        jr      nz,_sleep_convlp

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

_sleep_times10:
        add     hl,hl   ;*2
        ld      d,h
        ld      e,l
        add     hl,hl   ;*4
        add     hl,hl   ;*8
        add     hl,de   ;*10
        ret

str_usage: DEFM "usage: sleep <X>\n X=0...9999 msec\n"
str_usage_end:

        SECTION DATA
_sleep_max:     defs    1
