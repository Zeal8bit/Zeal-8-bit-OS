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

        ; Performs a CALL (HL)
        MACRO CALL_HL _
                rst 0x18
        ENDM

        EXTERN is_alpha_numeric
        EXTERN strncmp

        ENDIF