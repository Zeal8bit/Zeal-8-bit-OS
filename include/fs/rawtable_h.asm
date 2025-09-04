; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "fs/fs_h.asm"

    IFNDEF RAWTABLE_H
    DEFINE RAWTABLE_H

    EXTERN rawtable_struct
    DEFC FS_RAWTABLE = (rawtable_struct - __FS_VECTORS_head) / FS_STRUCT_SIZE

    ENDIF ; RAWTABLE_H