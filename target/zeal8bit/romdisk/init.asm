; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "syscalls_h.asm"

        ORG 0x4000

_start:
        ; Try to print a message on the screen,
        ld h, DEV_STDOUT
        ; Put the buffer address in DE
        ld de, welcome
        ; Pass the buffer size in BC
        ld bc, welcome_end - welcome
        ; Call WRITE!
        SYSCALL_WRITE()

loop:   halt
        jp loop

welcome:
        DEFM "Hello, world!\nI am init the program, I am part of a romdisk.\n"
        DEFM "If you can see this message on screen, the kernel did its job.\n", 0
welcome_end: