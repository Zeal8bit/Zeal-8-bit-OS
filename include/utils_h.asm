; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        IFNDEF UTILS_H
        DEFINE UTILS_H

        ; Performs ADD HL, A
        MACRO ADD_HL_A _
                add l
                ld l, a
                adc h
                sub l
                ld h, a
        ENDM

        ; Performs ADD DE, A
        MACRO ADD_DE_A _
                add e
                ld e, a
                adc d
                sub e
                ld d, a
        ENDM

        ; Performs a CALL (HL)
        MACRO CALL_HL _
                rst 0x10
        ENDM

        ; Allocate 256 bytes on the stack
        ; Alters: HL, SP
        MACRO ALLOC_STACK_256 _
                ld hl, -256
                add hl, sp
                ld sp, hl
        ENDM

        ; Free the 256 bytes allocated on the stack
        ; Alters: HL, SP
        MACRO FREE_STACK_256 _
                ld hl, 256
                add hl, sp
                ld sp, hl
        ENDM

        ; Convert a literal 16-bit value into string
        MACRO STR lit
                STRHEX((lit >> 12) & 0xf)
                STRHEX((lit >> 8) & 0xf)
                STRHEX((lit >> 4) & 0xf)
                STRHEX((lit >> 0) & 0xf)
        ENDM

        MACRO STRHEX param
                if ((param) < 0xa)
                        DEFB ((param) + '0')
                else
                        DEFB ((param) - 10 + 'a')
                endif
        ENDM

        EXTERN is_alpha_numeric
        EXTERN strncmp

        ENDIF