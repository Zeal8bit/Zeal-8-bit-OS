; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    EXTERN to_lower

    ; Convert all characters of the given string to lowercase
    ; Parameters:
    ;       HL - Address of the string to convert
    ; Alters:
    ;       A
    PUBLIC strtolower
strtolower:
    push hl
_strtolower_loop:
    ld a, (hl)
    or a
    jr z, _strtolower_end
    call to_lower
    ld (hl), a
    inc hl
    jr nz, _strtolower_loop
_strtolower_end:
    pop hl
    ret