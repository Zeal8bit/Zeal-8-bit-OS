; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .section .text

    ; Look for the delimiter A in the string pointed by HL
    ; Once it finds it, the token is replace by \0.
    ; Parameters:
    ;       HL - Address of the string
    ;       BC - Size of the string
    ;       A - Delimiter
    ; Returns:
    ;       HL - Original string address
    ;       DE - Address of the next string (address of the token found +1)
    ;       BC - Length of the remaining string
    ;       A - 0 if the delimiter was found, non-null value else
    ; Alters:
    ;       DE, BC, A
    .globl memsep
memsep:
    ld d, h
    ld e, l
    cpir
    ; Regardless whether BC is 0 is not, we have to check the last character
    ; and replace it. This is due to the fact that if the separator is the
    ; last character of the string, BC will still be 0, even though we've
    ; found it.
    dec hl
    sub (hl)
    jr nz, _memsep_not_set
    ld (hl), a
    _memsep_not_set:
    inc hl
    ex de, hl
    ret
