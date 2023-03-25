; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        IFNDEF RAWTABLE_H
        DEFINE RAWTABLE_H

        ; Public routines. The descriptions are given in the implementation file.
        EXTERN zos_fs_rawtable_open
        EXTERN zos_fs_rawtable_stat
        EXTERN zos_fs_rawtable_read
        EXTERN zos_fs_rawtable_write
        EXTERN zos_fs_rawtable_close
        EXTERN zos_fs_rawtable_opendir
        EXTERN zos_fs_rawtable_readdir
        EXTERN zos_fs_rawtable_mkdir
        EXTERN zos_fs_rawtable_rm

        ENDIF ; RAWTABLE_H