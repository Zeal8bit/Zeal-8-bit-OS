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

        EXTERN is_alpha_numeric
        EXTERN strncmp

        ENDIF