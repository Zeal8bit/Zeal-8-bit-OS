; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>, Martin Barth <github:ufobat>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    ; Checks if the NULL-terminated string in DE is the beginning of the
    ; NULL-terminated string in HL.
    ; Parameters:
    ;   HL - First NULL-terminated string
    ;   DE - Second NULL-terminated string
    ; Returns:
    ;   A - 0 AND Z-Flag, if DE is the beginning
    ;       Negative value if HL > DE
    ;       Positive value if HL < DE
    ; Alters:
    ;   A
    PUBLIC str_startswith
str_startswith:
        push hl
        push de
        dec hl
        dec de
_str_startswith_loop:
        inc hl
        inc de
        ld a, (de)
        or a                        ; Check if DE has reached the end
        jr z, _str_startswith_end
        sub (hl)
        jr z, _str_startswith_loop
_str_startswith_end:
        pop de
        pop hl
        ret