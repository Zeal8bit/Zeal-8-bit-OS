; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    ; Function copying src string into dest, including the terminating null byte.
    ; This function does not save HL and DE.
    ; Parameters:
    ;   HL - source string
    ;   DE - destination string
    ; Returns:
    ;   HL - Points to the character AFTER the NULL byte
    ;   DE - Points to the character AFTER the NULL byte
    ; Alters
    ;   A, HL, DE
    PUBLIC strcpy_raw
strcpy_raw:
    push bc
    ld bc, 0xffff
_strcpy_loop:
    ld a, (hl)
    ; Copy byte into de, even if it's null-byte
    ldi
    ; Test null-byte here
    or a
    jp nz, _strcpy_loop
    pop bc
    ret
