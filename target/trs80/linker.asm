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
        ; Target specific sections
        SECTION KERNEL_DRV_TEXT
        SECTION KERNEL_DRV_VECTORS

        ; RAM data
        SECTION KERNEL_BSS
        ORG CONFIG_KERNEL_RAM_START
        SECTION DRIVER_BSS
