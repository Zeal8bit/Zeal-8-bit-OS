; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    EXTERN to_upper

    ; Convert all characters of the given string to uppercase
    ; Parameters:
    ;       HL - Address of the string to convert
    ; Alters:
    ;       A
    PUBLIC strtoupper
strtoupper:
    push hl
_strtoupper_loop:
    ld a, (hl)
    or a
    jr z, _strtoupper_end
    call to_upper
    ld (hl), a
    inc hl
    jr nz, _strtoupper_loop
_strtoupper_end:
    pop hl
    ret
