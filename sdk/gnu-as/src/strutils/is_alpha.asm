; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .section .text

    .extern is_lower
    .extern is_upper

    ; Check if character in A is a letter [A-Za-z]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not an alpha char
    ;   not carry flag - Is an alpha char
    .globl is_alpha
is_alpha:
    call is_lower
    ret nc   ; Return on success
    jp is_upper

