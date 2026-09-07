; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .section .text

    .extern is_digit

    ; Check if character in A is a hex digit [0-9a-fA-F]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not a hex digit
    ;   not carry flag - Is a hex digit
    .globl is_hex_digit
is_hex_digit:
    call is_digit
    ret nc  ; return on success
    cp 'A'
    ret c   ; error
    cp 'F' + 1
    jp c, _hex_digit
    cp 'a'
    ret c
    cp 'f' + 1
_hex_digit:
    ccf
    ret
