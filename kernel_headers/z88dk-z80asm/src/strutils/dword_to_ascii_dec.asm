; SPDX-FileCopyrightText: 2023 Shawn Sijnstra <shawn@sijnstra.com>;
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    ; Convert a 32-bit unsigned value to ASCII (%u format)
    ; Parameters:
    ;       HL - pointer to 32 bit value in little endian (source)
    ;       DE - String destination. It must have 10 free bytes to write the ASCII result.
    ; Returns:
    ;       DE - DE + 10
    ;       HL - HL + 4
    ; Alters:
    ;       A, DE, HL, contents of original 32 bit value now zero.
    PUBLIC dword_to_ascii_dec
dword_to_ascii_dec:
    push bc ;preserve bc
    push de ;destination address
    push hl ;put the source address on the stack
    ld bc,2560 + 32 ;b=10 digits to clear, c=4*8 for the loop
    ld hl,9
    add hl,de
    ld d,h  ;de now has outbuf + 9
    ld e,l
    xor a
_pde_u_zerobuf:
    ld (hl),a  ;zero out the output
    dec hl
    djnz _pde_u_zerobuf

_bcd_Convert:

    pop hl  ;hl has source address again
    push hl
    sla (hl)
    inc hl
    rl (hl)
    inc hl
    rl (hl)
    inc hl
    rl (hl)

    ld b,10  ;num output digits
    ld h,d
    ld l,e

_bcd_Add6:
    ld a,(hl)
    adc a
    daa             ;built-in add 6 routine
    cp 0x10 ;Check for half-carry
    ccf     ;make carry available for next byte
    res 4,a ;clear bit without changing flags
    ld (hl),a
    dec hl
    djnz _bcd_Add6  ;it's add 6 instead of 3 because it's done after the shift
    dec c
    jr nz, _bcd_Convert

    pop de ;de now has the source address
    pop hl ;hl now has the string address
    ld bc,0x930     ;b = 9, c = 0x30
    xor a
_pde_u_make_ascii:
    or (hl)
    jr nz,_pde_u_make_ascii2
    ld (hl),' '
    inc hl
    djnz _pde_u_make_ascii
_pde_u_make_ascii2:
    inc b
_pde_u_make_ascii3:
    ld a,(hl)
    or c ;turn into ascii
    ld (hl),a
    inc hl
    djnz _pde_u_make_ascii3
;hl is now just after the end of the buffer string
    ex de,hl
    inc hl ;add 4 for consistency with hex version
    inc hl
    inc hl
    inc hl
    pop bc
    ret
