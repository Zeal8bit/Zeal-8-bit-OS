; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "zos_sys.asm"
        
        SECTION TEXT
        
        ; Parse the options from the ARGV (which contains 2 entries)
        ; Parameters:
        ;       HL - ARGV given by the caller
        ;       DE - String containing at most 8 parameters (ASCII chars)
        ;            for example 'l1'
        ; Returns:
        ;       A - 0 - Success, 1 - Invalid options given or not starting with '-'
        ;       C - Bitmap of the given parameters. For the given string above
        ;           For example, if l is given, B will be 1.
        ;                        if 1 is given, B will be 2.
        ; Alters:
        ;       A, C, DE, HL
        PUBLIC get_options
get_options:
get_params:
        ; Initialize the bitmap
        ld c, 0
        ; Point to the first real parameter
        inc hl
        inc hl
        ; Dereference it in HL directly
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        ; Check the option string, it must begin with '-'
        ld a, (hl)
        sub '-'
        jp nz, _get_params_invalid_parameter
        ; Check that the next byte is NOT NULL
        inc hl
        or (hl)
        jp z, _get_params_invalid_parameter
        jp _get_params_no_inc
_get_params_loop:
        inc hl
        ld a, (hl)
        or a
        ret z   ; end of parsing
_get_params_no_inc:
        call get_param_in_de
        ; Returns A = 1 if in DE, A = 0 else
        ; Returns the index of the option in B.
        or a
        jp z, _get_params_invalid_parameter
        ; Make sure B is NOT 0 else djnz would loop 256 times
        inc b
_get_param_shift_a:
        rlca
        djnz _get_param_shift_a
        ; We rotated A one time more than necessary, compensate
        rrca
        ; Apply the mask to the bitmap
        or c
        ld c, a
        jp _get_params_loop
_get_params_invalid_parameter:
        ld a, 1
        ret


        ; Check if a character is in the given options string, returns
        ; the index of it when found.
        ; Parameters:
        ;       A - Character to search 
        ;       DE - String to search the character in
        ; Returns:
        ;       A - 1 when found, 0 else
        ;       B - Index where it was found
        ; Alters:
        ;       A, B
get_param_in_de:
        push de
        push bc
        ld b, 0 ; index
        ; Put the character to look for in C instead
        ld c, a
        ; Compare one by one, stop when we find \0 or the char itself
_get_param_in_de_next:
        ld a, (de)
        or a
        jp z, _get_param_in_de_not_found
        cp c
        jr z, _get_param_in_de_found
        inc de
        inc b
        jp _get_param_in_de_next
_get_param_in_de_not_found:
        pop bc
        pop de
        xor a   ; Not found
        ret
_get_param_in_de_found:
        ld a, b
        pop bc
        ld b, a
        pop de
        ld a, 1 ; Found
        ret
