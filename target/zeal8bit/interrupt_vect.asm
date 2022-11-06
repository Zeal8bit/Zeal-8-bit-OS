; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        ; Source file for grouping the interrupt vectors
        ; It must be aligned on 256 in the linker script
        INCLUDE "interrupt_h.asm"

        SECTION INTERRUPT_VECTOR

        PUBLIC interrupt_vector_table
        ALIGN 256
interrupt_vector_table:
        DEFW interrupt_default_handler
        DEFW interrupt_pio_handler