; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        IFNDEF SYSCALL_H
        DEFINE SYSCALL_H

        DEFC DEV_STDOUT = 0
        DEFC DEV_STDIN = 1
        DEFC DISKS_DIR_ENTRY_SIZE = 17
        DEFC CONFIG_KERNEL_PATH_MAX = 128
        DEFC MAX_FILE_NAME = 16

        ; Define the bit index for the WRONLY flag.
        DEFC O_WRONLY_BIT = 0
        ; Flags for opening devices/files
        DEFC O_RDONLY = 0 << O_WRONLY_BIT
        DEFC O_WRONLY = 1 << O_WRONLY_BIT
        DEFC O_RDWR   = 2
        DEFC O_TRUNC  = 1 << 2
        DEFC O_APPEND = 2 << 2
        DEFC O_CREAT  = 3 << 2
        ; Only makes sense for drivers, not files
        DEFC O_NONBLOCK = 1 << 4

        DEFC STAT_STRUCT_SIZE = 28

        MACRO SYSCALL
                rst 0x8
        ENDM

        MACRO  READ  _
                ld l, 0 
                SYSCALL
        ENDM

        MACRO S_READ1 dev
                ld h, dev
                READ()
        ENDM

        MACRO S_READ2 dev, str
                ld h, dev
                ld de, str
                READ()
        ENDM

        MACRO S_READ3 dev, str, len
                ld h, dev
                ld de, str
                ld bc, len
                READ()
        ENDM
        

        MACRO  WRITE  _
                ld l, 1 
                SYSCALL
        ENDM

        MACRO S_WRITE1 dev
                ld h, dev
                WRITE()
        ENDM

        MACRO S_WRITE2 dev, str
                ld h, dev
                ld de, str
                WRITE()
        ENDM

        MACRO S_WRITE3 dev, str, len
                ld h, dev
                ld de, str
                ld bc, len
                WRITE()
        ENDM

        MACRO  OPEN  _
                ld l, 2 
                SYSCALL
        ENDM
        

        MACRO  CLOSE  _
                ld l, 3 
                SYSCALL
        ENDM
        

        MACRO  DSTAT  _
                ld l, 4 
                SYSCALL
        ENDM
        

        MACRO  STAT  _
                ld l, 5 
                SYSCALL
        ENDM
        

        MACRO  SEEK  _
                ld l, 6 
                SYSCALL
        ENDM
        

        MACRO  IOCTL  _
                ld l, 7 
                SYSCALL
        ENDM
        

        MACRO  MKDIR  _
                ld l, 8 
                SYSCALL
        ENDM
        

        MACRO  CHDIR  _
                ld l, 9 
                SYSCALL
        ENDM
        

        MACRO  CURDIR  _
                ld l, 10 
                SYSCALL
        ENDM
        

        MACRO  OPENDIR  _
                ld l, 11 
                SYSCALL
        ENDM
        

        MACRO  READDIR  _
                ld l, 12 
                SYSCALL
        ENDM
        

        MACRO  RM  _
                ld l, 13 
                SYSCALL
        ENDM
        

        MACRO  MOUNT  _
                ld l, 14 
                SYSCALL
        ENDM
        

        MACRO  EXIT  _
                ld l, 15 
                SYSCALL
        ENDM
        

        MACRO  EXEC  _
                ld l, 16 
                SYSCALL
        ENDM
        

        MACRO  DUP  _
                ld l, 17 
                SYSCALL
        ENDM
        

        MACRO  MSLEEP  _
                ld l, 18 
                SYSCALL
        ENDM
        

        MACRO  SETTIME  _
                ld l, 19 
                SYSCALL
        ENDM
        

        MACRO  GETTIME  _
                ld l, 20 
                SYSCALL
        ENDM
        

        MACRO  MAP  _
                ld l, 23 
                SYSCALL
        ENDM

        ENDIF