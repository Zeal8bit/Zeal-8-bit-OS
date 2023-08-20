; SPDX-FileCopyrightText: 2023 Shawn Sijnstra <shawn@sijnstra.com>
;
; SPDX-License-Identifier: Apache-2.0

; eZ80F92 GPIO ports
PB_DR:                  EQU             09Ah
PB_DDR:                 EQU             09Bh
PB_ALT1:                EQU             09Ch
PB_ALT2:                EQU             09Dh
PC_DR:                  EQU             09Eh
PC_DDR:                 EQU             09Fh
PC_ALT1:                EQU             0A0h
PC_ALT2:                EQU             0A1h
PD_DR:                  EQU             0A2h
PD_DDR:                 EQU             0A3h
PD_ALT1:                EQU             0A4h
PD_ALT2:                EQU             0A5h

        IFNDEF INTERRUPT_H
        DEFINE INTERRUPT_H

        MACRO ENTER_CRITICAL _
                di
        ENDM

        MACRO EXIT_CRITICAL _
                ei
        ENDM

        MACRO INTERRUPTS_ENABLE _
                im 2
                ei
        ENDM
; Set a GPIO register
; Parameters:
; - REG: Register to set
; - VAL: Bit(s) to set (1: set, 0: ignore)
;
SET_GPIO: MACRO   REG, VAL
        IN0     A,(REG)
        OR      VAL
        OUT0    (REG),A
        ENDM

        EXTERN interrupt_vector_table
        EXTERN interrupt_default_handler
        EXTERN interrupt_pio_handler

        ENDIF