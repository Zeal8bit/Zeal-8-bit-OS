; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    EXTERN is_lower
    EXTERN is_upper

    ; Check if character in A is a letter [A-Za-z]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not an alpha char
    ;   not carry flag - Is an alpha char
    PUBLIC is_alpha
is_alpha:
    call is_lower
    ret nc   ; Return on success
    jp is_upper
