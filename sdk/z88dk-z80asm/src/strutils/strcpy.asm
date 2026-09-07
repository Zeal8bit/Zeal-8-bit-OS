; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    ; Function copying src string into dest, including the terminating null byte
    ; Parameters:
    ;   HL - source string
    ;   DE - destination string
    ; Alters
    ;   A
    PUBLIC strcpy
strcpy:
    push hl
    push bc
    push de
    ld bc, 0xffff
_strcpy_loop:
    ld a, (hl)
    ; Copy byte into de, even if it's null-byte
    ldi
    ; Test null-byte here
    or a
    jp nz, _strcpy_loop
    pop de
    pop bc
    pop hl
    ret
