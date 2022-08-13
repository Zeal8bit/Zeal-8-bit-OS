; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "errors_h.asm"

    SECTION KERNEL_STRLIB

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

    ; Trim trailing space character from a string pointed by HL
    ; Parameters:
    ;   HL - NULL-terminated string to trim leading spaces from
    ;   BC - Length of the string
    ; Returns:
    ;   HL - Address of the non-space character from the string
    ;   BC - Length of the remaining string
    ; Alters:
    ;   A
    PUBLIC strrtrim
strrtrim:
    push hl
    add hl, bc
    inc bc
_strrtrim_loop:
    ; Decrement BC and check if it is 0
    dec bc
    ld a, b
    or c
    jr z, _strrtrim_end
    dec hl
    ld a, ' '
    cp (hl)
    jr z, _strrtrim_loop
    inc hl
    ld (hl), 0
_strrtrim_end:
    pop hl
    ret

    ; Compare two NULL-terminated strings pointed by HL and DE.
    ; If they are identical, A will be 0
    ; If DE is greater than HL, A will be positive
    ; If HL is greater than DE, A will be negative
    ;
    ; Alters:
    ;       A
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

    ; Look for a character in a NULL-terminated string.
    ; Parameter:
    ;   HL - Source string (must NOT be NULL)
    ;   A - Delimiter
    ; Returns:
    ;   A - Delimiter if found, 0 if not found
    ;   HL - Address of the delimiter byte if found, or NULL byte if not found
    ; Alters:
    ;   A, HL
    PUBLIC strchrnul
strchrnul:
    push bc
    ld b, a
_strchr_loop:
    ld a, (hl)
    or a
    jr z, _strchr_ret
    cp b
    inc hl
    jr nz, _strchr_loop
_strchr_ret:
    pop bc
    ret


    ; Compare two NULL-terminated strings pointed by HL and DE.
    ; At most BC bytes will be read.
    ; If they are identical, A will be 0
    ; If DE is greater than HL, A will be positive
    ; If HL is greater than DE, A will be negative
    ;
    ; Alters:
    ;       A
    PUBLIC strncmp
strncmp:
    push hl
    push de
    push bc
    dec hl
    dec de
    inc bc
_strncmp_compare:
    dec bc
    inc hl
    inc de
    ld a, b
    or c
    jr z, _strncmp_end
    ld a, (de)
    sub (hl)
    jr nz, _strncmp_end
    ; Check if both strings have reached the end
    ; If this is the case, or (hl) will reset in zero flag to be set
    ; In that case, no need to continue, we can return, with flag Z set
    or (hl) 
    jr nz, _strncmp_compare
_strncmp_end:
    pop bc
    pop de
    pop hl
    ret

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
    IF 0
    ; BC shall NOT be 0!
    ; Save A before erasing it
    ld e, a
    ld a, b
    or c
    ld a, e
    ret z
    ENDIF

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

    ; Look for the delimiter A in the string pointed by HL
    ; Once it finds it, the token is replace by \0.
    ; Parameters:
    ;       HL - Address of the string
    ;       A  - Delimiter
    ; Returns:
    ;       HL - Original string address
    ;       DE - Address of the next string (address of the token found +1)
    ;       A - 0 if the delimiter was found, non-null value else
    ; Alters:
    ;       DE, A
    PUBLIC strsep
strsep:
    push bc
    call strlen
    call memsep
    pop bc
    ret

    ; Calculate the length of a NULL-terminated string
    ; Parameters:
    ;       HL - Address of the string
    ; Returns:
    ;       BC - Size of the string
    ; Alters:
    ;       A
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
    cpir
_strlen_end:
    pop hl
    ret

    IF 0
strlen:
    push hl
    ld a, 0xff
    ld b, a
    ld c, a
    inc a
    cpir
    dec a
    sub b
    ld b, a
    ld a, 0xff
    sbc a, c
    ld c, a 
    pop hl
    ret
    ENDIF

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

    PUBLIC strcpy_unsaved
strcpy_unsaved:
    ld a, (hl)
    ld (de), a
    inc hl
    inc de
    or a
    jp nz, strcpy_unsaved
    ret

    ; Same as strcpy but if src is smaller than the given size,
    ; the destination buffer will be filled with 0
    ; Parameters:
    ;       HL - src string
    ;       DE - dst string
    ;       BC - maximum bytes to write
    ; Alters:
    ;       A
    PUBLIC strncpy
strncpy:
    ; Make sure that BC is not 0, else, nothing to copy
    ld a, b
    or c
    ret z
    ; Size is not 0, we can proceed
    push hl
    push de
    push bc
_strncpy_loop:
    ; Read the src byte, to check null-byte
    ld a, (hl)
    ; We cannot use ldir here as we need to check the null-byte in src
    ldi
    or a
    jp z, _strncpy_zero
    ld a, b
    or c
    jp nz, _strncpy_loop
_strncpy_end:
    pop bc
    pop de
    pop hl
    ret
_strncpy_zero:
    ; Here too, we have to test whether BC is 0 or not
    ld a, b
    or c
    jp z, _strncpy_end
    ; 0 has just been copied to dst (DE), we can reuse this null byte to fill
    ; the end of the buffer using LDIR
    ld hl, de
    ; Make hl point to the null-byte we just copied
    dec hl
    ; Perform the copy
    ldir
    jp _strncpy_end

    ; Concatenate two strings by writing at most BC bytes, including NULL byte.
    ; This function will add NULL-terminating byte.
    ; Parameters:
    ;   HL - Destination string
    ;   DE - Source to copy at the end of HL
    ;   BC - Maximum bytes to copy (including \0)
    ; Returns:
    ;   A - 0 if success, 1 if result is too long
    ;   DE - Address of the former NULL-byte of HL
    ; Alters:
    ;   A
    PUBLIC strncat
strncat:
    push hl
    push bc
    xor a
    cpir
    ; Test is BC is 0!
    ld a, b
    or c
    ld a, 1 ; In case of an error
    jp z, _strncat_src_null
    ; HL points to the address past the NULL-byte.
    ; Similarly, BC has counted the NULL-byte
    dec hl
    push hl     ; Former NULL-byte
    ; We should now copy bytes until BC is 0 or [DE] is 0
    ex de, hl
_strncat_copy:
    xor a
    or (hl)
    ldi
    jp z, _strncat_pop_de
    ; Check if BC is 0
    ld a, b
    or c
    jp nz, _strncat_copy
    ; BC is 0, terminate dst and return
    ld (de), a
    ; We have to return A > 0 so increment
    inc a
_strncat_pop_de:
    pop de
_strncat_src_null:
    ; We've met a null pointer in src, which was copied successfully
    ; A is already 0, we can return
    pop bc
    pop hl
    ret

    ; Convert all characters of the given string to lowercase
    ; Parameters:
    ;       HL - Address of the string to convert
    ; Alters:
    ;       A
    PUBLIC strtolower
strtolower:
    push hl
_strtolower_loop:
    ld a, (hl)
    or a
    jr z, _strtolower_end
    call to_lower
    ld (hl), a
    inc hl
    jr nz, _strtolower_loop
_strtolower_end:
    pop hl
    ret


    ; Convert all characters of the given string to uppercase
    ; Parameters:
    ;       HL - Address of the string to convert
    ; Alters:
    ;       A
    PUBLIC strtoupper
strtoupper:
    push hl
_strtoupper_loop:
    ld a, (hl)
    jr z, _strtoupper_end
    call to_upper
    ld (hl), a
    inc hl
    jr nz, _strtoupper_loop
_strtoupper_end:
    pop hl
    ret

    ; Initialize the memory pointed by HL with the byte passed in A
    ; Parameters:
    ;       HL - Memory address to initialize
    ;       BC - Size of the memory to initialize
    ;       E  - Byte to initialize the memory with
memset:
    ; Test that BC is not null
    ld a, b
    or c
    ret z
    ; BC is not 0, we can proceed
    push hl
    push de
    push bc
    ; Put the character to fill the memory with in A and load HL with it
    ld a, e
    ld (hl), a
    ; As we just filled the buffer with a byte, we have to decrement BC and
    ; check once again whether it is null or not
    dec bc
    ld a, b
    or c
    jp z, _memset_end
    ; DE (destination) must point to the address following HL
    ld d, h
    ld e, l
    inc de
    ; Start the copy
    ldir
 _memset_end:
    pop bc
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


    ;;;;;;;;;;;;;;;;;;; Characters utils ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; Subroutine checking that the byte contained in A
    ; is printable
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

    ; Subroutine checking that the byte contained in A
    ; is alpha numeric [A-Za-z0-9]
    ;   carry flag - Not an alpha numeric
    ;   not carry flag - Is an alpha numeric
    PUBLIC is_alpha_numeric
is_alpha_numeric:
    call is_alpha
    ret nc  ; Return on success
    jr is_digit

    ; Subroutine checking that the byte contained in A
    ; is a letter [A-Za-z]
    ; Returns:
    ;   carry flag - Is an alpha char
    ;   not carry flag - Is not an alpha char
is_alpha:
    call is_lower
    ret nc   ; Return on success
    jr is_upper

    ; Subroutine checking that the byte contained in A
    ; is a lower case letter [a-z]
    ; Returns:
    ;   carry flag - Not a lower char
    ;   not carry flag - Is a lower char
is_lower:
    cp 'a'
    ret c
    cp 'z' + 1         ; +1 because p flag is set when result is 0
    ccf
    ret

    ; Subroutine checking that the byte contained in A
    ; is an upper case letter [A-Z]
    ; Returns:
    ;   carry flag - Not an upper char
    ;   not carry flag - Is an upper char
is_upper:
    cp 'A'
    ret c   ; Return if carry because we shouldn't have a carry here
    cp 'Z' + 1         ; +1 because p flag is set when result is 0
    ccf
    ret

    ; Subroutine checking that the byte contained in A
    ; is a digit [0-9]
    ; Returns:
    ;   carry flag - Not a digit
    ;   not carry flag - Is a digit
    PUBLIC is_digit
is_digit:
    cp '0'
    ret c
    cp '9' + 1         ; +1 because if A = '9', p flag would be set
    ccf
    ret

    ; Subroutine checking that the byte contained in A
    ; is a hex digit [0-9a-fA-F]
    ; Returns:
    ;   carry flag - Not a hex digit
    ;   not carry flag - Is a hex digit
is_hex_digit:
    call is_digit
    ret nc  ; return on success
    cp 'A'
    ret c   ; error
    cp 'F' + 1
    jp c, _hex_digit
    cp 'a'
    ret c
    cp 'f' + 1
_hex_digit:
    ccf
    ret

    ; Subroutine checking that the byte contained in A
    ; is a whitespace
    ;   carry flag - Not a whitespace
    ;   not carry flag - Is a whitespace
is_whitespace:
    cp ' '
    ret z   ; No carry when result is 0
    cp '\t'
    ret z
    cp '\n'
    ret z
    cp '\r'
    ret z
    scf
    ret

    ; Subroutine converting a character to a lower case
    ; Parameter:
    ;   A - Character to convert
    PUBLIC to_lower
to_lower:
    cp 'A'
    jp c, _to_lower_not_char
    cp 'Z' + 1         ; +1 because p flag is set when result is 0
    jp nc, _to_lower_not_char
    add 'a' - 'A'
    ret
_to_lower_not_char:
    ret

    ; Subroutine converting a character to an upper case
    ; Parameter:
    ;   A - Character to convert
    ; Returns:
    ;   carry flag - Invalid parameter
    ;   not carry flag - Success
    PUBLIC to_upper
to_upper:
    ; Check if it's already an upper char
    call is_upper
    ret nc  ; Already upper, can exit
    cp 'a'
    ret c   ; Error, return
    cp 'z' + 1         ; +1 because p flag is set when result is 0
    jp nc, _to_lower_not_char_ccf
    sub 'a' - 'A'
    scf
_to_lower_not_char_ccf:
    ccf
    ret


    ; Convert an 8-bit value to ASCII
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
    ; If the byte is between 0 and 9 included, add '0'
    sub 10
    jp nc, _byte_to_ascii_af
    ; Byte is between 0 and 9
    add '0' + 10
    ret
_byte_to_ascii_af:
    ; Byte is between A and F
    add 'A'
    ret
