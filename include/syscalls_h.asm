; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        IFNDEF SYSCALLS_H
        DEFINE SYSCALLS_H

        ; Syscall table
        ; Syscall name  =  Syscall number
        DEFC SYSCALL_MAP_NUMBER = (syscall_map - zos_syscalls_table) / 2
        DEFC SYSCALL_MAP_ROUTINE = zos_sys_map
        DEFC SYSCALL_EXEC_NUMBER = (syscall_exec - zos_syscalls_table) / 2
        DEFC SYSCALL_EXIT_NUMBER = (syscall_exit - zos_syscalls_table) / 2

        DEFC SYSCALL_COUNT = (zos_syscalls_table_end - zos_syscalls_table) / 2

        ENDIF