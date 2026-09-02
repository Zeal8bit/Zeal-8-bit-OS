; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .section .text

    ; Check if character in A is printable
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not printable char
    ;   not carry flag - Is a printable char
    .globl is_print
is_print:
    ; Printable characters are above 0x20 (space) and below 0x7F
    cp ' '
    ret c
    cp 0x7F
    ccf
    ret

