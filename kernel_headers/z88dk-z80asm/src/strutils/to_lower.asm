; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    ; Subroutine converting a character to a lower case
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   A - Lower case character on success, same character else
    PUBLIC to_lower
to_lower:
    cp 'A'
    jp c, _to_lower_not_char
    cp 'Z' + 1         ; +1 because p flag is set when result is 0
    jp nc, _to_lower_not_char
    add 'a' - 'A'
    ret
_to_lower_not_char:
    ret
