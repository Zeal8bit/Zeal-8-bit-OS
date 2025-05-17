; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    EXTERN is_alpha
    EXTERN is_digit

    ; Check if character in A is alpha numeric [A-Za-z0-9]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not an alpha numeric
    ;   not carry flag - Is an alpha numeric
    PUBLIC is_alpha_numeric
is_alpha_numeric:
    call is_alpha
    ret nc  ; Return on success
    jp is_digit