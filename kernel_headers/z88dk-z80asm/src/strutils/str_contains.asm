; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>, Martin Barth <github:ufobat>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    EXTERN str_startswith

    ; str_contains: Checks if a substring is present within a string.
    ; Parameters:
    ;       HL - Address of the main string (null-terminated).
    ;       DE - Address of the substring (null-terminated).
    ; Result:
    ;       A - 0 if the substring is found, 1 if it is NOT found.
    ; Alters: AF, BC, DE, HL, IX
    PUBLIC str_contains
str_contains:
        push hl          ; Save main string pointer
_str_contains_outer_loop:
        ld a, (hl)                      ; Load character from main string
        or a                            ; Check for null terminator
        jr z, _str_contains_not_found   ; If end of main string, not found
        call str_startswith             ; Compare substring with current portion of main string
        jr z, _str_contains_found       ; If strcmp returns 0 (strings are equal), substring found
        inc hl                          ; Move to next character in main string
        jr _str_contains_outer_loop
_str_contains_not_found:
        ld a, 1         ; Substring not found
        jp _str_contains_end
_str_contains_found:
        ld a, 0         ; Substring found
_str_contains_end:
        pop hl          ; Restore main string pointer
        ret
