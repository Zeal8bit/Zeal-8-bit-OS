; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .section .text

    .extern byte_to_ascii

    ; Convert a date (DATE_STRUCT) to ASCII.
    ; The format will be as followed:
    ; YYYY-MM-DD HH:MM:SS
    ; Parameters:
    ;       HL - Pointer to the date structure, of size DATE_STRUCT_SIZE
    ;       DE - String destination. It must have at least 19 bytes free
    ; Returns:
    ;       HL - HL + DATE_STRUCT_SIZE
    ;       DE - DE + 19
    .globl date_to_ascii
date_to_ascii:
    push bc
    ld b, h
    ld c, l
    ; HL will be used as a destination
    ex de, hl
    ; Read the year top digits first
    ld a, (bc)
    call _date_to_ascii_digits
    ld a, (bc)
    call _date_to_ascii_digits
    ld (hl), '-'
    inc hl
    ; BC points to the month now
    ld a, (bc)
    call _date_to_ascii_digits
    ld (hl), '-'
    inc hl
    ; BC points to the day now
    ld a, (bc)
    call _date_to_ascii_digits
    ld (hl), ' '
    inc hl
    ; Skip the day name
    inc bc
    ; Hours
    ld a, (bc)
    call _date_to_ascii_digits
    ld (hl), ':'
    inc hl
    ; Minutes
    ld a, (bc)
    call _date_to_ascii_digits
    ld (hl), ':'
    inc hl
    ; Seconds
    ld a, (bc)
    call _date_to_ascii_digits
    ; Restore HL, DE and BC
    ex de, hl
    ld h, b
    ld l, c
    pop bc
    ret
_date_to_ascii_digits:
    call byte_to_ascii
    ld (hl), e
    inc hl
    ld (hl), d
    inc hl
    inc bc
    ret
