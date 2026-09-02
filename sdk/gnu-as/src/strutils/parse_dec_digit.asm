; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .section .text


    ; Convert an ASCII character representing a decimal digit to its binary value
    ; Parameters:
    ;  A - ASCII character to convert
    ; Returns:
    ;  A - Value on success (carry clear)
    ;      Preserved on failure (carry set)
    .globl parse_dec_digit
parse_dec_digit:
    cp '0'
    ret    c
    cp '9' + 1
    ccf
    ret c
    ; A is between '0' and '9'
    sub '0' ; CY will be reset
    ret
