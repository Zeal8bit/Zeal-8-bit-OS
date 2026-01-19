
; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .section .text

    ; Check if character in A is a lower case letter [a-z]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not a lower char
    ;   not carry flag - Is a lower char
    .globl is_lower
is_lower:
    cp 'a'
    ret c
    cp 'z' + 1         ; +1 because p flag is set when result is 0
    ccf
    ret
