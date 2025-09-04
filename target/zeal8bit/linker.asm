; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0
        INCLUDE "osconfig.asm"

        ; Code and read-only data
        SECTION RST_VECTORS
        ORG 0
        SECTION SYSCALL_ROUTINES
        ; This section, SYSCALL_TABLE, must be aligned on 256
        SECTION SYSCALL_TABLE
        SECTION KERNEL_TEXT
        SECTION KERNEL_STRLIB
        SECTION KERNEL_RODATA
        ; File systems related
        SECTION FS_VECTORS
        ; Target specific sections
        SECTION KERNEL_DRV_TEXT
        SECTION KERNEL_DRV_VECTORS
        ; Add a dummy section whose size is as big as the padding
        ; between the end of KERNEL_DRV_VECTORS and the beginning
        ; of INTERRUPT_VECTOR section. This is needed in order not to
        ; alter the real size of KERNEL_DRV_VECTORS, while being able to have
        ; the 256-alignment on INTERRUPT_VECTOR section.
        SECTION KERNEL_PADDING
        SECTION INTERRUPT_VECTOR

        ; RAM data
        SECTION KERNEL_BSS
        ORG CONFIG_KERNEL_RAM_START
        SECTION DRIVER_BSS
        SECTION DRIVER_BSS_ALIGN16
        ; MMU is initialized before the kernel erases the BSS, thus we cannot
        ; store MMU data inside the BSS, create a new section that won't be erased
        ; by the kernel.
        SECTION NOINIT_DATA