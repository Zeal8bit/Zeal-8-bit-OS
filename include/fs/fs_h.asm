; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    IFNDEF FS_H
    DEFINE FS_H

    ; Provide a macro for defining a filesystem
    MACRO NEW_FS_STRUCT name, open, stat, read, write, close, opendir, readdir, mkdir, rm
        DEFS 4, name
        DEFW open
        DEFW stat
        DEFW read
        DEFW write
        DEFW close
        DEFW opendir
        DEFW readdir
        DEFW mkdir
        DEFW rm
        DEFW 0  ; Padding
    ENDM

    ; The structure defined above must have a size of 24 bytes
    DEFC FS_STRUCT_SIZE = 24

    DEFC FS_OFF_OPEN    = 4
    DEFC FS_OFF_STAT    = 6
    DEFC FS_OFF_READ    = 8
    DEFC FS_OFF_WRITE   = 10
    DEFC FS_OFF_CLOSE   = 12
    DEFC FS_OFF_OPENDIR = 14
    DEFC FS_OFF_READDIR = 16
    DEFC FS_OFF_MKDIR   = 18
    DEFC FS_OFF_RM      = 20

    EXTERN __FS_VECTORS_head
    EXTERN __FS_VECTORS_tail
    EXTERN __FS_VECTORS_size

    ENDIF