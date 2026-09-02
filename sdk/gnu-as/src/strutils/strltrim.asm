; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .section .text


    ; Trim leading space character from a string pointed by HL
    ; Parameters:
    ;   HL - NULL-terminated string to trim leading spaces from
    ;   BC - Length of the string
    ; Returns:
    ;   HL - Address of the non-space character from the string
    ;   BC - Length of the remaining string
    ; Alters:
    ;   A
    .globl strltrim
strltrim:
    dec hl
    inc bc
_strltrim_loop:
    inc hl
    dec bc
    ; Return if BC is 0 now
    ld a, b
    or c
    ret z
    ld a, ' '
    cp (hl)
    jp z, _strltrim_loop
    ret
