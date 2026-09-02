; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    ; Check if character in A is a whitespace
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not a whitespace
    ;   not carry flag - Is a whitespace
    PUBLIC is_whitespace
is_whitespace:
    cp ' '
    ret z   ; No carry when result is 0
    cp '\t'
    ret z
    cp '\n'
    ret z
    cp '\r'
    ret z
    scf
    ret
