; SPDX-FileCopyrightText: 2024 Shawn Sijnstra <shawn@sijnstra.com>
;
; SPDX-License-Identifier: Apache-2.0


        INCLUDE "zos_sys.asm"

        SECTION TEXT

        EXTERN error_print
        EXTERN strlen

        MACRO ERR_CHECK goto_label
                or a
                jp nz, goto_label
        ENDM

        ; "echo" command main function
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        PUBLIC echo_main
echo_main:
        ; Check that argc is at 2 (command itself is part of argc)
        ld a, c
        cp 2
        jp nz, _echo_usage
         ; Retrieve the number given as a parameter
        inc hl
        inc hl  ; skip the first pointer
        ld e,(hl)       ;grab 2nd pointer
        inc hl
        ld d,(hl)
        ex de,hl        ;pointer in HL
        call strlen ;returns answer in BC
        ex de,hl ;DE has the string address
        S_WRITE1(DEV_STDOUT) ;DE has address, BC has length
        S_WRITE3(DEV_STDOUT, str_usage_end -1,1) ;newline
        xor a   ;success
        ret


_echo_usage:
        S_WRITE3(DEV_STDOUT, str_usage, str_usage_end - str_usage)
        ld a, 1
        ret

_echo_error:
        ; Give NULL to error_print to have a default error message
        ld de, 0
        call error_print
        ld a, 2
        ret

str_usage: DEFM "usage:\n"
        DEFM " echo <string> sends a copy of <string> to STDOUT\n"
str_usage_end:

