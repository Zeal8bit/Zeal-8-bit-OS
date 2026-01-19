; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .section .text

    .equ TAB, 0x09
    .equ NEWLINE, 0x0A
    .equ CARRIAGE_RETURN, 0x0D

    ; Check if character in A is a whitespace
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not a whitespace
    ;   not carry flag - Is a whitespace
    .globl is_whitespace
is_whitespace:
    cp ' '
    ret z   ; No carry when result is 0
    cp TAB
    ret z
    cp NEWLINE
    ret z
    cp CARRIAGE_RETURN
    ret z
    scf
    ret
