; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    ; Look for a character in a NULL-terminated string
    ; Parameter:
    ;   HL - Source string address, must NOT be NULL
    ;   A  - Delimiter
    ; Returns:
    ;   A  - Delimiter if found, 0 if not found
    ;   HL - Address of the delimiter byte if found, or NULL byte if not found
    ; Alters:
    ;   A, HL
    PUBLIC strchrnul
strchrnul:
    push bc
    ld b, a
_strchr_loop:
    ld a, (hl)
    or a
    jr z, _strchr_ret
    cp b
    inc hl
    jr nz, _strchr_loop
_strchr_ret:
    pop bc
    ret
