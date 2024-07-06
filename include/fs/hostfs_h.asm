; SPDX-FileCopyrightText: 2024 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "osconfig.asm"

    IFNDEF HOSTFS_H
    DEFINE HOSTFS_H

    IF CONFIG_ENABLE_EMULATION_HOSTFS

    ; Public routines. The descriptions are given in the implementation file.
    EXTERN zos_fs_hostfs_open
    EXTERN zos_fs_hostfs_read
    EXTERN zos_fs_hostfs_write
    EXTERN zos_fs_hostfs_opendir
    EXTERN zos_fs_hostfs_readdir
    EXTERN zos_fs_hostfs_stat
    EXTERN zos_fs_hostfs_close
    EXTERN zos_fs_hostfs_mkdir
    EXTERN zos_fs_hostfs_rm

    ; Private defines
    DEFC IO_ARG0_REG  = 0xC0
    DEFC IO_ARG1_REG  = 0xC1
    DEFC IO_ARG2_REG  = 0xC2
    DEFC IO_ARG3_REG  = 0xC3
    DEFC IO_ARG4_REG  = 0xC4
    DEFC IO_ARG5_REG  = 0xC5
    DEFC IO_ARG6_REG  = 0xC6
    DEFC IO_ARG7_REG  = 0xC7

    DEFC IO_OPERATION = 0xCF            ; WO
    DEFC IO_STATUS    = IO_OPERATION    ; RO

    DEFC OP_WHOAMI  = 0
    DEFC OP_OPEN    = 1
    DEFC OP_STAT    = 2
    DEFC OP_READ    = 3
    DEFC OP_WRITE   = 4
    DEFC OP_CLOSE   = 5
    DEFC OP_OPENDIR = 6
    DEFC OP_READDIR = 7
    DEFC OP_MKDIR   = 8
    DEFC OP_RM      = 9

    ENDIF ; CONFIG_ENABLE_EMULATION_HOSTFS


    ENDIF ; ZEALFS_H
