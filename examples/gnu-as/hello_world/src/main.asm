; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: CC0-1.0

    ; Include the Zeal 8-bit OS header file, containing all the syscalls macros.
    .include "zos_sys.asm"

    ; The .text section will be linked at address `0x4000`
    .text

    .global _start
_start:
    ; Print a message on the standard output. As we know at compile time the
    ; message and its length, we can use the S_WRITE3 macro.
    S_WRITE3 DEV_STDOUT, _message, _message_end - _message

    ; We MUST execute EXIT() syscall at the end of any program.
    ; Exit code is stored in H, 0 means success.
    ld h, 0
    EXIT()

    .size _start, . - _start

    .data
    ; Define a label before and after the message, so that we can get the length
    ; of the string thanks to `_message_end - _message`.
_message: .ascii "Hello World!\n"
_message_end:
