; SPDX-FileCopyrightText: 2023 Shawn Sijnstra <shawn@sijnstra.com>
;
; SPDX-License-Identifier: Apache-2.0

        ; Source file for grouping the interrupt vectors
        ; It must be aligned on 256 in the linker script
        INCLUDE "interrupt_h.asm"

        SECTION INTERRUPT_VECTOR

        PUBLIC interrupt_vector_table
        ALIGN 256
;        set_vector(PORTB1_IVECT, vblank_handler);       // 0x32
interrupt_vector_table:
        DEFW interrupt_default_handler  ;00
        DEFW interrupt_default_handler  ;02
        DEFW interrupt_default_handler  ;04
        DEFW interrupt_default_handler  ;06
        DEFW interrupt_default_handler  ;08
        DEFW interrupt_default_handler  ;0A
        DEFW interrupt_default_handler  ;0C
        DEFW interrupt_default_handler  ;0E
        DEFW interrupt_default_handler  ;10
        DEFW interrupt_default_handler  ;12
        DEFW interrupt_default_handler  ;14
        DEFW interrupt_default_handler  ;16
        DEFW interrupt_default_handler  ;18
        DEFW interrupt_default_handler  ;1A
        DEFW interrupt_default_handler  ;1C
        DEFW interrupt_default_handler  ;1E
        DEFW interrupt_default_handler  ;20
        DEFW interrupt_default_handler  ;22
        DEFW interrupt_default_handler  ;24
        DEFW interrupt_default_handler  ;26
        DEFW interrupt_default_handler  ;28
        DEFW interrupt_default_handler  ;2A
        DEFW interrupt_default_handler  ;2C
        DEFW interrupt_default_handler  ;2E
        DEFW interrupt_default_handler  ;30
        DEFW interrupt_pio_handler
        DEFW interrupt_default_handler  ;34
        DEFW interrupt_default_handler  ;36
        DEFW interrupt_default_handler  ;38
        DEFW interrupt_default_handler  ;3A
        DEFW interrupt_default_handler  ;3C
        DEFW interrupt_default_handler  ;3E
        DEFW interrupt_default_handler  ;40
        DEFW interrupt_default_handler  ;42
        DEFW interrupt_default_handler  ;44
        DEFW interrupt_default_handler  ;46
        DEFW interrupt_default_handler  ;48
        DEFW interrupt_default_handler  ;4A
        DEFW interrupt_default_handler  ;4C
        DEFW interrupt_default_handler  ;4E
        DEFW interrupt_default_handler  ;50
        DEFW interrupt_default_handler  ;52
        DEFW interrupt_default_handler  ;54
        DEFW interrupt_default_handler  ;56
        DEFW interrupt_default_handler  ;58
        DEFW interrupt_default_handler  ;5A
        DEFW interrupt_default_handler  ;5C
        DEFW interrupt_default_handler  ;5E
        