
; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    ; Convert an ASCII character representing a hex digit to its binary value
    ; Parameters:
    ;  A - ASCII character to convert
    ; Returns:
    ;  A - Value on success (carry clear)
    ;      Preserved on failure (carry set)
    PUBLIC parse_hex_digit
parse_hex_digit:
    cp '0'
    ret c
    cp '9' + 1
    jp c, _parse_hex_dec_digit
    cp 'A'
    ret c
    cp 'F' + 1
    jp c, _parse_upper_hex_digit
    cp 'a'
    ret c
    cp 'f' + 1
    ccf
    ret c
_parse_lower_hex_digit:
    ; A is a character between 'a' and 'f'
    sub 'a' - 10 ; CY will be reset
    ret
_parse_upper_hex_digit:
    ; A is a character between 'A' and 'F'
    sub 'A' - 10 ; CY will be reset
    ret
_parse_hex_dec_digit:
    ; A is between '0' and '9'
    sub '0' ; CY will be reset
    ret
