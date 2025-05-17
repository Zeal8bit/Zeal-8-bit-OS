; SPDX-FileCopyrightText: 2024 Shawn Sijnstra <shawn@sijnstra.com>
;
; SPDX-License-Identifier: Apache-2.0


        INCLUDE "zos_sys.asm"
        INCLUDE "zos_err.asm"
        INCLUDE "strutils_h.asm"

        SECTION TEXT

        EXTERN error_print
        EXTERN init_static_buffer

        MACRO ERR_CHECK goto_label
                or a
                jp nz, goto_label
        ENDM

        ; "expr" command main function
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        PUBLIC expr_main
expr_main:

         ; Retrieve the number given as a parameter
        inc hl
        inc hl  ; skip the first pointer
        ld e,(hl)   ;grab 2nd pointer
        inc hl
        ld d,(hl)
        ex de,hl    ;pointer in HL
        ; Check that argc is at least 2 (command itself is part of argc)
        ; This may need to change in future as we allow to evaluate full expressions
        ld a, c
        sub 2
        jp c, _expr_usage
        jp nz, _expr_do_string  ;can only be string related function now

_expr_do_math:
        call parse_int ;strutils - accepts 16 bit dec or hex input at HL
        or a           ;0 is ok, 1 is overflow, 2 is bad digit
        jr nz,_expr_usage

        ; Routine displaying the value of HL in decimal then hex
        ; Parameters:
        ;   HL - number to display
        ; Returns:
        ;   A - zero
        ;   successful return to ZealOS
        ; note this destroys the init_static_buffer

_expr_print_result:
        push hl
        ld (init_static_buffer),hl
        ld hl,0
        ld (init_static_buffer+2),hl
        ld hl,init_static_buffer
        ld de,init_static_buffer+4
        call dword_to_ascii_dec
        ld hl,init_static_buffer+4
        ld bc,10
        call strltrim
        ex de,hl
        S_WRITE1(DEV_STDOUT)
        S_WRITE3(DEV_STDOUT, str_gap,3)
        pop hl
        ld a, h
        call byte_to_ascii
        ld a, l
        ld hl, init_static_buffer
        ld (hl), e
        inc hl
        ld (hl), d
        inc hl
        call byte_to_ascii
        ld (hl), e
        inc hl
        ld (hl), d
        inc hl
        ld (hl), '\n'
        S_WRITE3(DEV_STDOUT, init_static_buffer, 5)
        xor a
        ret

_expr_do_string:
        ; Check that argc is 3 (command itself is part of argc)
        ; format is "expr l string" which outputs the length of the string
        dec a
        jr nz, _expr_usage
        ld a,(hl)
        cp 'l'
        jr nz,_expr_error ;it's not the 'length' command so invalid parameter.
        ex de,hl ;hl back to pointer table
        inc hl   ; we didn't inc before
        ld e,(hl)  ;grab 3rd pointer
        inc hl
        ld d,(hl)
        ex de,hl     ;pointer in HL
        call strlen  ;returns answer in BC
        ld h,b
        ld l,c
        jp _expr_print_result


_expr_usage:
        S_WRITE3(DEV_STDOUT, str_usage, str_usage_end - str_usage)
        ld a, 1
        ret

_expr_error:
        ; Give NULL to error_print to have a default error message
        ld de, 0
        ld a, ERR_INVALID_PARAMETER
        call error_print
        ld a,2
        ret

str_usage:      DEFM "usage:\n"
                DEFM " expr <X> evaluate the hex or decimal number <X>\n"        ;this will be ((expression)) when ready
                DEFM " expr l <string> evaluate the length of string\n"
                DEFM " Results are shown in decimal and hex\n"
str_usage_end:
str_gap:        DEFM " 0x"

