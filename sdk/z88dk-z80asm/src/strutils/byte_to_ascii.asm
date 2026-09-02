; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT


    ; Convert an 8-bit value to ASCII (%x format)
    ; Parameters:
    ;       A - Value to convert
    ; Returns:
    ;       E - First character
    ;       D - Second character
    ; Alters:
    ;       A
    PUBLIC byte_to_ascii
byte_to_ascii:
    ld d, a
    rlca
    rlca
    rlca
    rlca
    and 0xf
    call _byte_to_ascii_nibble
    ld e, a
    ld a, d
    and 0xf
    call _byte_to_ascii_nibble
    ld d, a
    ret
_byte_to_ascii_nibble:
    ; efficient routine to convert nibble into ASCII
    add a, 0x90
    daa
    adc a, 0x40
    daa
    ret