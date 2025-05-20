; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "errors_h.asm"
    INCLUDE "strutils_h.asm"

    EXTERN _vfs_work_buffer_end
    DEFC WORK_BUFFER = _vfs_work_buffer_end - 4

    SECTION KERNEL_STRLIB

    ; Format the given string with parameters passed on the stack.
    ; The string to format can specify special parameters thanks to the FORMAT_*
    ; macros. These parameters must be pushed on the stack from right to left.
    ; In other words, the first parameter that the parser will encounter must
    ; be on the top of the stack. The stack will be cleaned by this routine.
    ; Note:
    ;   This routine uses 4 bytes at the end of the _vfs_work_buffer
    ; Parameters:
    ;   HL - Address of the string to format
    ;   DE - Destination to store the result, must be big enough to hold all
    ;        the characters.
    ; Returns:
    ;   DE - Destination
    ; Alters:
    ;   A, HL, BC
    PUBLIC strformat
strformat:
    ; Store return address in work ram
    ex (sp), hl
    ld (WORK_BUFFER), hl
    ld (WORK_BUFFER + 2), de
    pop hl
_str_format_loop:
    ld a, (hl)
    and a
    jp m, _str_format_special
    jr z, _str_format_end
    ldi
    jp _str_format_loop
_str_format_special:
    ; Check format specifier, remove upper bit
    and FORMAT_SPECIFIER_MASK
    jr z, _str_format_char_array
    dec a
    jr z, _str_format_str
    dec a
    jr z, _str_format_hex
    dec a
    jr z, _str_format_char
    ; Unknown, skip it
    inc hl
    jr _str_format_loop
_str_format_char_array:
    ; Store 0 in B
    ld b, a
    ; Similar to string but with a limited amount of bytes
    ; Get the amount of bytes to copy from (HL)
    ld a, (hl)
    rrca
    rrca
    rrca
    rrca
    and 0x7
    ld c, a
    ; BC contains the size to copy, get the source string from the stack
    ex (sp), hl
    ldir
    jr _str_format_restore_continue
_str_format_str:
    ex (sp), hl
_str_format_str_loop:
    ld a, (hl)
    or a
    jr z, _str_format_restore_continue
    ldi
    jr _str_format_str_loop
_str_format_hex:
    ex (sp), hl
    ; Only H contains data
    ld a, h
    ; Use HL to save DE
    ex de, hl
    call byte_to_ascii
    ; Save D and E inside HL
    ld (hl), d
    inc hl
    ld (hl), e
    inc hl
    ex de, hl
    jr _str_format_restore_continue
_str_format_char:
    ex (sp), hl
    ld a, h
    ld (de), a
    inc de
_str_format_restore_continue:
    pop hl
    inc hl
    jr _str_format_loop
_str_format_end:
    ; Store the NULL byte at the end of the buffer
    ld (de), a
    ; Get back the original destination buffer and the return address
    ld de, (WORK_BUFFER + 2)
    ld hl, (WORK_BUFFER)
    jp (hl)


    ; Trim leading space character from a string pointed by HL
    ; Parameters:
    ;   HL - String to trim leading spaces from
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
    ;   HL - String to trim leading spaces from
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

    ; Compare two NULL-terminated strings.
    ; Parameters:
    ;   HL - First NULL-terminated string address
    ;   DE - Second NULL-terminated string address
    ; Returns:
    ;   A - 0 if strings are identical
    ;       > 0 if DE is greater than HL
    ;       < 0 if HL is greater than DE
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


    ; Same as strcmp, but at most BC bytes will be read.
    ; Parameters:
    ;   HL - First NULL-terminated string address
    ;   DE - Second NULL-terminated string address
    ;   BC - Maximum number of char to compare
    ; Returns:
    ;   A - 0 if strings are identical
    ;       > 0 if DE is greater than HL
    ;       < 0 if HL is greater than DE
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


    ; Look for a character in a NULL-terminated string
    ; Parameter:
    ;   HL - Source string address, must NOT be NULL
    ;   A  - Delimiter
    ; Returns:
    ;   A  - Delimiter if found, 0 if not found
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


    ; Look for the delimiter A in the string pointed by HL
    ; Once it finds it, the token is replace by \0
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
    ;       A, DE, BC
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


    ; Look for the delimiter A in the string pointed by HL
    ; Once it finds it, the token is replace by \0
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
    xor a
    ld b, a
    ld c, a
    push hl
    cpir
    ; Calculate 0x10000 - BC - 1
    ld h, 0xff
    ld l, h
    sbc hl, bc
    ld b, h
    ld c, l
    pop hl
    ret

    ; Copy a NULL-terminated string into a given address, including the terminating NULL-byte.
    ; Parameters:
    ;       HL - Source string address
    ;       DE - Destination address
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

    ; Same as strcpy but if the source address is smaller than the given size,
    ; the destination buffer will be filled with NULL (\0) byte.
    ; Parameters:
    ;       HL - Source string address
    ;       DE - Destination string address
    ;       BC - Maximum number of bytes to write
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


    ; Initialize the memory pointed by HL with the byte given in E.
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
    ; 0x or $, decimal number start with any valid digit
    ; Parameters:
    ;       HL - NULL-terminated string to parse
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


    ; Check if character in A is alpha numeric [A-Za-z0-9]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not an alpha numeric
    ;   not carry flag - Is an alpha numeric
    PUBLIC is_alpha_numeric
is_alpha_numeric:
    call is_alpha
    ret nc  ; Return on success
    jr is_digit

    ; Check if character in A is a letter [A-Za-z]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not an alpha char
    ;   not carry flag - Is an alpha char
is_alpha:
    call is_lower
    ret nc   ; Return on success
    jr is_upper


    ; Check if character in A is a lower case letter [a-z]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not a lower char
    ;   not carry flag - Is a lower char
is_lower:
    cp 'a'
    ret c
    cp 'z' + 1         ; +1 because p flag is set when result is 0
    ccf
    ret

    ; Check if character in A is an upper case letter [A-Z]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not an upper char
    ;   not carry flag - Is an upper char
is_upper:
    cp 'A'
    ret c   ; Return if carry because we shouldn't have a carry here
    cp 'Z' + 1         ; +1 because p flag is set when result is 0
    ccf
    ret


    ; Check if character in A is a digit [0-9]
    ; Parameters:
    ;   A - ASCII character
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


    ; Check if character in A is a hex digit [0-9a-fA-F]
    ; Parameters:
    ;   A - ASCII character
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


    ; Check if character in A is a whitespace
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
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
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   A - Lower case character on success, same character else
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


    ; Convert an ASCII character to upper case
    ; Parameter:
    ;   A - ASCII character
    ; Returns:
    ;   A - Upper case character on success, same character else
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
    ;       D - First ASCII character
    ;       E - Second ASCII character
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
