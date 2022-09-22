; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        SECTION TEXT

        ; Look for the delimiter A in the string pointed by HL
        ; Once it finds it, the token is replace by \0.
        ; Parameters:
        ;       HL - Address of the string
        ;       BC - Size of the string
        ;       A - Delimiter
        ; Returns:
        ;       HL - Original string address
        ;       DE - Address of the next string (address of the token found +1)
        ;       BC - Length of the remaining string
        ;       A - 0 if the delimiter was found, non-null value else
        ; Alters:
        ;       DE, BC, A
        PUBLIC memsep
memsep:
        ld de, hl
        cpir
        ; Regardless whether BC is 0 is not, we have to check the last character
        ; and replace it. This is due to the fact that if the separator is the
        ; last character of the string, BC will still be 0, even though we've
        ; found it.
        dec hl
        sub (hl)
        jr nz, _memsep_not_set
        ld (hl), a
        _memsep_not_set:
        inc hl
        ex de, hl
        ret

        ; Trim leading space character from a string pointed by HL
        ; Parameters:
        ;   HL - NULL-terminated string to trim leading spaces from
        ;   BC - Length of the string
        ; Returns:
        ;   HL - Address of the non-space character from the string
        ;   BC - Length of the remaining string
        ; Alters:
        ;   A
        PUBLIC strltrim
strltrim:
        dec hl
        inc bc
_strltrim_loop:
        inc hl
        dec bc
        ; Return if BC is 0 now
        ld a, b
        or c
        ret z
        ld a, ' '
        cp (hl)
        jp z, _strltrim_loop
        ret

        ; Routine returning the length of a NULL-terminated string
        ; Parameters:
        ;   HL - NULL-terminated string to get the length from
        ; Returns:
        ;   BC - Length of the string
        ; Alters:
        ;   A, BC
        PUBLIC strlen
strlen:
        push hl
        xor a
        ld b, a
        ld c, a
_strlen_loop:
        cp (hl)
        jr z, _strlen_end
        inc hl
        inc bc
        jr _strlen_loop
_strlen_end:
        pop hl
        ret

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
        PUBLIC parse_int
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

        PUBLIC parse_hex
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

        PUBLIC parse_dec
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

parse_oct_digit:
        cp '0'
        jp c, _parse_not_oct_digit
        cp '7' + 1
        jp nc, _parse_not_oct_digit
        ; A is between '0' and '7'
        sub '0' ; CY will be reset
        ret
_parse_not_oct_digit:
        scf
        ret

parse_dec_digit:
        cp '0'
        jp c, _parse_not_dec_digit
        cp '9' + 1
        jp nc, _parse_not_dec_digit
        ; A is between '0' and '9'
        sub '0' ; CY will be reset
        ret
_parse_not_dec_digit:
        scf
        ret

parse_hex_digit:
        cp '0'
        jp c, _parse_not_hex_digit
        cp '9' + 1
        jp c, _parse_hex_dec_digit
        cp 'A'
        jp c, _parse_not_hex_digit
        cp 'F' + 1
        jp c, _parse_upper_hex_digit
        cp 'a'
        jp c, _parse_not_hex_digit
        cp 'f' + 1
        jp nc, _parse_not_hex_digit
_parse_lower_hex_digit:
        ; A is a character between 'a' and 'f'
        sub 'a' - 10 ; CY will be reset
        ret
_parse_upper_hex_digit:
        ; A is a character between 'A' and 'F'
        sub 'A' - 10 ; CY will be reset
        ret
_parse_hex_dec_digit:
        ; A is a character between '0' and '9'
        sub '0' ; CY will be reset
        ret
_parse_not_hex_digit:
        scf
        ret
