; SPDX-FileCopyrightText: 2023-4 Zeal 8-bit Computer <contact@zeal8bit.com>;
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

        ; Replace a byte by another in an array.
        ; Parameters:
        ;   A - Old byte to replace
        ;   L - New byte
        ;   DE - Memory address
        ;   BC - Memory length
        ; Returns:
        ;   BC - 0
        ;   HL - Memory address + memory length (DE + BC)
        ; Alters:
        ;   A, HL, BC, DE
        PUBLIC memrep
memrep:
        ex de, hl
_memrep_loop:
        ; New byte in E
        cpir
        ; If z flag is not set, BC is 0
        ret nz
        ; Replace old byte with the new one
        dec hl
        ld (hl), e
        inc hl
        ; Still need to check if BC is 0
        ld d, a
        ld a, b
        or c
        ld a, d
        jp nz, _memrep_loop
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



    ; Function copying src string into dest, including the terminating null byte
        ; Parameters:
        ;       HL - src string
        ;       DE - dst string
        ; Alters
        ;       A
        PUBLIC strcpy
strcpy:
        push hl
        push bc
        push de
        ld bc, 0xffff
_strcpy_loop:
        ld a, (hl)
        ; Copy byte into de, even if it's null-byte
        ldi
        ; Test null-byte here
        or a
        jp nz, _strcpy_loop
        pop de
        pop bc
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

;Convert lower nibble in A from ASCII to octal digit
;Parameters:
;  A is ASCII character to convert
;returns:
;  success: A has hex value, carry clear
;  fail: A preserved, carry set

parse_oct_digit:
        cp '0'
        ret c
        cp '7' + 1
        ccf
        ret c
        ; A is between '0' and '7'
        sub '0' ; CY will be reset
        ret


;Convert lower nibble in A from ASCII to decimal digit
;Parameters:
;  A is ASCII character to convert
;returns:
;  success: A has hex value, carry clear
;  fail: A preserved, carry set

        PUBLIC parse_dec_digit
parse_dec_digit:
        cp '0'
        ret    c
        cp '9' + 1
        ccf
        ret c
_parse_hex_dec_digit:
        ; A is between '0' and '9'
        sub '0' ; CY will be reset
        ret

;Convert lower nibble in A from ASCII to hex digit
;Parameters:
;  A is ASCII character to convert
;returns:
;  success: A has hex value, carry clear
;  fail: A preserved, carry set

        PUBLIC parse_hex_digit
parse_hex_digit:
        cp '0'
        ret c
        cp '9' + 1
        jp c, _parse_hex_dec_digit
        cp 'A'
        ret c
        cp 'F' + 1
        jp c, _parse_upper_hex_digit
        cp 'a'
        ret c
        cp 'f' + 1
        ccf
        ret c
_parse_lower_hex_digit:
        ; A is a character between 'a' and 'f'
        sub 'a' - 10 ; CY will be reset
        ret
_parse_upper_hex_digit:
        ; A is a character between 'A' and 'F'
        sub 'A' - 10 ; CY will be reset
        ret


        ; Convert a 32-bit value to ASCII (hex)
        ; Parameters:
        ;       HL - Pointer to a 32-bit value, little-endian
        ;       DE - String destination. It must have at least 8 free bytes to write the ASCII result.
        ; Returns:
        ;       HL - HL + 4
        ;       DE - DE + 8
        ; Alters:
        ;       A, DE
        PUBLIC dword_to_ascii
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
        ld (hl), d
        inc hl
        ld (hl), e
        inc hl
        ret

        ; Convert an 8-bit value to ASCII (hex)
        ; Parameters:
        ;       A - Value to convert
        ; Returns:
        ;       D - First character
        ;       E - Second character
        ; Alters:
        ;       A
        PUBLIC byte_to_ascii
byte_to_ascii:
        ld e, a
        rlca
        rlca
        rlca
        rlca
        and 0xf
        call _byte_to_ascii_nibble
        ld d, a
        ld a, e
        and 0xf
        call _byte_to_ascii_nibble
        ld e, a
        ret
_byte_to_ascii_nibble:
        ; efficient routine to convert nibble into ASCII
        add a, 0x90
        daa
        adc a,040h
        daa
        ret

        ; Convert a date (DATE_STRUCT) to ASCII.
        ; The format will be as followed:
        ; YYYY-MM-DD HH:MM:SS
        ; Parameters:
        ;       HL - Pointer to the date structure, of size DATE_STRUCT_SIZE
        ;       DE - String destination. It must have at least 19 bytes free
        ; Returns:
        ;       HL - HL + DATE_STRUCT_SIZE
        ;       DE - DE + 19
        PUBLIC date_to_ascii
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
        ld (hl), d
        inc hl
        ld (hl), e
        inc hl
        inc bc
        ret


        ; Check if character in A is printable
        ; Parameters:
        ;   A - ASCII character
        ; Returns:
        ;   carry flag - Not printable char
        ;   not carry flag - Is a printable char
        PUBLIC is_print
is_print:
        ; Printable characters are above 0x20 (space) and below 0x7F
        cp ' '
        ret c
        cp 0x7F
        ccf
        ret
