; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

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

        EXTERN interrupt_vector_table
        EXTERN interrupt_default_handler
        EXTERN interrupt_pio_handler

        ENDIF