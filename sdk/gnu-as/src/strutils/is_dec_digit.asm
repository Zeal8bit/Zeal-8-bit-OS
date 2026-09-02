; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .section .text

    .extern is_digit

    ; Check if character in A is a decimal digit [0-9]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not a digit
    ;   not carry flag - Is a digit
    .globl is_dec_digit
is_dec_digit:
    cp '0'
    ret c
    cp '9' + 1         ; +1 because if A = '9', p flag would be set
    ccf
    ret

