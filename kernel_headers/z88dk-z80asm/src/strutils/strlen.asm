; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    ; Routine returning the length of a NULL-terminated string
    ; Parameters:
    ;   HL - NULL-terminated string to get the length from
    ; Returns:
    ;   BC - Length of the string
    ; Alters:
    ;   A, BC
    PUBLIC strlen
strlen:
    push hl
    xor a
    ld b, a
    ld c, a
_strlen_loop:
    cp (hl)
    jr z, _strlen_end
    inc hl
    inc bc
    jr _strlen_loop
_strlen_end:
    pop hl
    ret