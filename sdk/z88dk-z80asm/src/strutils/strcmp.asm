; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    ; Compare two NULL-terminated strings pointed by HL and DE.
    ; If they are identical, A will be 0
    ; If DE is greater than HL, A will be positive
    ; If HL is greater than DE, A will be negative
    ; Parameters:
    ;   HL - First NULL-terminated string
    ;   DE - Second NULL-terminated string
    ; Returns:
    ;   A - 0 if both are identical
    ;       Negative value if HL > DE
    ;       Positive value if HL < DE
    ; Alters:
    ;   A
    PUBLIC strcmp
strcmp:
    push hl
    push de
    dec hl
    dec de
_strcmp_compare:
    inc hl
    inc de
    ld a, (de)
    sub (hl)
    jr nz, _strcmp_end
    ; Check if both strings have reached the end
    ; If this is the case, or (hl) will reset in zero flag to be set
    ; In that case, no need to continue, we can return, with flag Z set
    or (hl)
    jr nz, _strcmp_compare
_strcmp_end:
    pop de
    pop hl
    ret