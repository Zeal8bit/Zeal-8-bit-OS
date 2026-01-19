; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .section .text

    .extern parse_hex_digit
    .extern parse_dec_digit

    ; Parse string into a 16-bit integer. Hexadecimal string can start with
    ; 0x or $, decimal number start with any
    ; valid digit
    ; Parameters:
    ;       HL - String to parse
    ; Returns:
    ;       HL - Parsed value
    ;       A - 0 if the string was parsed successfully
    ;           1 if the string represents a value bigger than 16-bit
    ;           2 if the string presents non-digit character(s)
    ; Alters:
    ;       A, HL
    .globl parse_int
parse_int:
    ld a, (hl)
    cp '$'
    jr z, _parse_hex_prefix
    cp '0'
    jr nz, parse_dec
    inc hl
    ld a, (hl)
    cp 'x'
    jr z, _parse_hex_prefix
    dec hl
    jr parse_dec

    .globl parse_hex
_parse_hex_prefix:
    inc hl  ; Go past prefix ($, 0x)
parse_hex:
    push de
    ex de, hl
    ld h, 0
    ld l, 0
    ld a, (de)
    or a
    jp z, _parse_hex_incorrect
_parse_hex_loop:
    call parse_hex_digit
    jr c, _parse_hex_incorrect
    ; Left shift HL 4 times
    add hl, hl
    jp c, _parse_hex_too_big
    add hl, hl
    jp c, _parse_hex_too_big
    add hl, hl
    jp c, _parse_hex_too_big
    add hl, hl
    jp c, _parse_hex_too_big
    or l
    ld l, a
    ; Go to next character and check whether it is the end of the string or not
    inc de
    ld a, (de)
    or a
    jp z, _parse_hex_end
    jp _parse_hex_loop
_parse_hex_too_big:
    ld a, 1
    pop de
    ret
_parse_hex_incorrect:
    ld a, 2
_parse_hex_end:
    pop de
    ret

    .globl parse_dec
parse_dec:
    push de ; DE wil contain the string to parse
    push bc ; BC will be a temporary register, for multiplying HL by 10
    ex de, hl
    ld h, 0
    ld l, 0
    ld a, (de)
    or a
    jp z, _parse_dec_incorrect
_parse_dec_loop:
    call parse_dec_digit
    jr c, _parse_dec_incorrect
    ; Multiple HL by 10!
    add hl, hl  ; HL = HL * 2
    jr c, _parse_dec_too_big
    push hl     ; HL * 2 pushed on the stack
    add hl, hl  ; HL = HL * 4
    jr c, _parse_dec_too_big_pushed
    add hl, hl  ; HL = HL * 8
    jr c, _parse_dec_too_big_pushed
    pop bc      ; BC contains HL * 2
    add hl, bc  ; HL = 2 * HL + 8 * HL = 10 * HL
    jr c, _parse_dec_too_big
    ld b, 0
    ld c, a
    ; Add the new digit to the result
    add hl, bc
    jr c, _parse_dec_too_big
    ; Go to next character and check whether it is the end of the string or not
    inc de
    ld a, (de)
    or a
    jp z, _parse_dec_end
    jp _parse_dec_loop
_parse_dec_too_big_pushed:
    ; We have to pop the saved 2*HL
    pop bc
_parse_dec_too_big:
    ld a, 1
    ; Pop back BC real value
    pop bc
    pop de
    ret
_parse_dec_incorrect:
    ld a, 2
_parse_dec_end:
    pop bc
    pop de
    ret
