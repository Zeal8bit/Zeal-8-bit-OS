; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        IFNDEF SYSCALLS_H
        DEFINE SYSCALLS_H

        ; Syscall instruction
        DEFM SYSCALL _
            rst zos_syscall
        ENDM

        ; Syscall table
        ; Syscall name  =  Syscall number
        DEFC SYSCALL_READ       = 0
        DEFC SYSCALL_WRITE      = 1
        DEFC SYSCALL_OPEN       = 2
        DEFC SYSCALL_CLOSE      = 3
        DEFC SYSCALL_DSTAT      = 4
        DEFC SYSCALL_STAT       = 5
        DEFC SYSCALL_SEEK       = 6
        DEFC SYSCALL_IOCTL      = 7
        DEFC SYSCALL_MKDIR      = 8
        DEFC SYSCALL_GETDIR     = 9
        DEFC SYSCALL_CHDIR      = 10
        DEFC SYSCALL_RDDIR      = 11
        DEFC SYSCALL_RM         = 12
        DEFC SYSCALL_MOUNT      = 13
        DEFC SYSCALL_EXIT       = 14
        DEFC SYSCALL_EXEC       = 15
        DEFC SYSCALL_DUP        = 16
        DEFC SYSCALL_MSLEEP     = 17
        DEFC SYSCALL_SETTIME    = 18
        DEFC SYSCALL_GETTIME    = 19
        DEFC SYSCALL_MAP        = 20

        ENDIF