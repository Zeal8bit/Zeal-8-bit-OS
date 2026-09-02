; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    ; Same as strcmp, but at most BC bytes will be read.
    ; Parameters:
    ;   HL - First NULL-terminated string address
    ;   DE - Second NULL-terminated string address
    ;   BC - Maximum number of char to compare
    ; Returns:
    ;   A - 0 if strings are identical
    ;       > 0 if DE is greater than HL
    ;       < 0 if HL is greater than DE
    ; Alters:
    ;       A
    PUBLIC strncmp
strncmp:
    push hl
    push de
    push bc
    dec hl
    dec de
    inc bc
_strncmp_compare:
    dec bc
    inc hl
    inc de
    ld a, b
    or c
    jr z, _strncmp_end
    ld a, (de)
    sub (hl)
    jr nz, _strncmp_end
    ; Check if both strings have reached the end
    ; If this is the case, or (hl) will reset in zero flag to be set
    ; In that case, no need to continue, we can return, with flag Z set
    or (hl)
    jr nz, _strncmp_compare
_strncmp_end:
    pop bc
    pop de
    pop hl
    ret
