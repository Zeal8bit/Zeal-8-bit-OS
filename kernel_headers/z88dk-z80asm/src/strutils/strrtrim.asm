; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    ; Trim trailing space character from a string pointed by HL
    ; Parameters:
    ;   HL - String to trim leading spaces from
    ;   BC - Length of the string
    ; Returns:
    ;   HL - Address of the non-space character from the string
    ;   BC - Length of the remaining string
    ; Alters:
    ;   A
    PUBLIC strrtrim
strrtrim:
    push hl
    add hl, bc
    inc bc
_strrtrim_loop:
    ; Decrement BC and check if it is 0
    dec bc
    ld a, b
    or c
    jr z, _strrtrim_end
    dec hl
    ld a, ' '
    cp (hl)
    jr z, _strrtrim_loop
    inc hl
    ld (hl), 0
_strrtrim_end:
    pop hl
    ret
