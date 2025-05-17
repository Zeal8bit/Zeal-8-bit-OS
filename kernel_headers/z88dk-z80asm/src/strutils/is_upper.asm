; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    ; Check if character in A is an upper case letter [A-Z]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not an upper char
    ;   not carry flag - Is an upper char
    PUBLIC is_upper
is_upper:
    cp 'A'
    ret c   ; Return if carry because we shouldn't have a carry here
    cp 'Z' + 1         ; +1 because p flag is set when result is 0
    ccf
    ret