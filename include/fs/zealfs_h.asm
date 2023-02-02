; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "osconfig.asm"

    IFNDEF ZEALFS_H
    DEFINE ZEALFS_H

    IF CONFIG_KERNEL_ENABLE_ZEALFS_SUPPORT

    ; Public routines. The descriptions are given in the implementation file.
    EXTERN zos_zealfs_open
    EXTERN zos_zealfs_read
    EXTERN zos_zealfs_write
    EXTERN zos_zealfs_opendir
    EXTERN zos_zealfs_readdir
    EXTERN zos_zealfs_stat
    EXTERN zos_zealfs_close
    EXTERN zos_zealfs_mkdir
    EXTERN zos_zealfs_rm

    DEFC zos_fs_zealfs_open    = zos_zealfs_open
    DEFC zos_fs_zealfs_read    = zos_zealfs_read
    DEFC zos_fs_zealfs_write   = zos_zealfs_write
    DEFC zos_fs_zealfs_stat    = zos_zealfs_stat
    DEFC zos_fs_zealfs_opendir = zos_zealfs_opendir
    DEFC zos_fs_zealfs_readdir = zos_zealfs_readdir
    DEFC zos_fs_zealfs_close   = zos_zealfs_close
    DEFC zos_fs_zealfs_mkdir   = zos_zealfs_mkdir
    DEFC zos_fs_zealfs_rm      = zos_zealfs_rm

    ELSE ; !CONFIG_KERNEL_ENABLE_ZEALFS_SUPPORT

    DEFC zos_fs_zealfs_open    = zos_disk_fs_not_supported
    DEFC zos_fs_zealfs_read    = zos_disk_fs_not_supported
    DEFC zos_fs_zealfs_write   = zos_disk_fs_not_supported
    DEFC zos_fs_zealfs_stat    = zos_disk_fs_not_supported
    DEFC zos_fs_zealfs_opendir = zos_disk_fs_not_supported
    DEFC zos_fs_zealfs_readdir = zos_disk_fs_not_supported
    DEFC zos_fs_zealfs_close   = zos_disk_fs_not_supported
    DEFC zos_fs_zealfs_mkdir   = zos_disk_fs_not_supported
    DEFC zos_fs_zealfs_rm      = zos_disk_fs_not_supported

    ENDIF ; CONFIG_KERNEL_ENABLE_ZEALFS_SUPPORT


    ENDIF ; ZEALFS_H
