; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .section .text

    .extern byte_to_ascii

    ; Convert a 32-bit value to a ASCII (%x format)
    ; Parameters:
    ;       HL - Pointer to a 32-bit value, little-endian
    ;       DE - String destination. It must have at least 8 free bytes to write the ASCII result.
    ; Returns:
    ;       HL - HL + 4
    ;       DE - DE + 8
    ; Alters:
    ;       A, DE, HL
    .globl dword_to_ascii
dword_to_ascii:
    push bc
    ld c, (hl)      ; Lowest byte
    inc hl
    ld b, (hl)
    inc hl
    push bc
    ld c, (hl)
    inc hl
    ld a, (hl)      ; Highest byte
    inc hl
    ; HL must be returned like this
    ex (sp), hl     ; HL contains lowest byte value now
    push hl
    ; Use HL as the destination, DE will be used as return value of byte_to_ascii
    ex de, hl
    call _dword_to_ascii_convert_store
    ld a, c
    call _dword_to_ascii_convert_store
    pop bc
    ld a, b
    call _dword_to_ascii_convert_store
    ld a, c
    call _dword_to_ascii_convert_store
    ; Put back the destination (HL) inside DE
    ex de, hl
    pop hl
    pop bc
    ret
_dword_to_ascii_convert_store:
    call byte_to_ascii
    ld (hl), e
    inc hl
    ld (hl), d
    inc hl
    ret
