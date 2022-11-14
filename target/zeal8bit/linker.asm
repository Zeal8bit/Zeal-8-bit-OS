; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        ; Code and read-only data
        SECTION RST_VECTORS
        ORG 0
        SECTION SYSCALL_ROUTINES
        ; This section, SYSCALL_TABLE, must be aligned on 256
        SECTION SYSCALL_TABLE
        SECTION KERNEL_TEXT
        SECTION KERNEL_STRLIB
        SECTION KERNEL_RODATA
        ; Target specific sections
        SECTION KERNEL_DRV_TEXT
        SECTION KERNEL_DRV_VECTORS
        ; Add a dummy section whose size is as big as the padding
        ; between the end of KERNEL_DRV_VECTORS and the beginning
        ; of INTERRUPT_VECTOR section. This is needed in order to not
        ; alter the real size of KERNEL_DRV_VECTORS, while being able to have
        ; the 256-alignment on INTERRUPT_VECTOR section.
        SECTION KERNEL_PADDING
        SECTION INTERRUPT_VECTOR

        ; RAM data
        SECTION KERNEL_BSS
        ORG 0xC000
        SECTION DRIVER_BSS
        SECTION DRIVER_BSS_ALIGN16
        ; MMU is initialized before the kernel erases the BSS, thus we cannot
        ; store MMU data inside the BSS, create a new section that won't be erased
        ; by the kernel.
        SECTION NOINIT_DATA