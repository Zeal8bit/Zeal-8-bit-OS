; SPDX-FileCopyrightText: 2023-2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "osconfig.asm"
    INCLUDE "fs/fs_h.asm"

    IFNDEF ZEALFS_H
    DEFINE ZEALFS_H

    IF CONFIG_KERNEL_ENABLE_ZEALFS_SUPPORT

    IF CONFIG_KERNEL_ZEALFS_V1
        DEFC ZEALFS_VERSION = 1
    ENDIF

    IF CONFIG_KERNEL_ZEALFS_V2
        DEFC ZEALFS_VERSION = 2
    ENDIF

    EXTERN zealfs_struct
    ; Define the index of the FS in the section FS_VECTORS
    DEFC FS_ZEALFS   = (zealfs_struct - __FS_VECTORS_head) / FS_STRUCT_SIZE

    ; Special case for the FS init, since it's not part of any structure
    EXTERN zos_zealfs_init

    ENDIF ; CONFIG_KERNEL_ENABLE_ZEALFS_SUPPORT


    ENDIF ; ZEALFS_H
