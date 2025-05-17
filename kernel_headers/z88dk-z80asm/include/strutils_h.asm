; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    IFNDEF STRUTILS_H
    DEFINE STRUTILS_H

    ; Convert an 8-bit value to ASCII (%x format)
    ; Parameters:
    ;       A - Value to convert
    ; Returns:
    ;       E - First character
    ;       D - Second character
    ; Alters:
    ;       A
    EXTERN byte_to_ascii


    ; Convert a date (DATE_STRUCT) to ASCII.
    ; The format will be as followed:
    ; YYYY-MM-DD HH:MM:SS
    ; Parameters:
    ;       HL - Pointer to the date structure, of size DATE_STRUCT_SIZE
    ;       DE - String destination. It must have at least 19 bytes free
    ; Returns:
    ;       HL - HL + DATE_STRUCT_SIZE
    ;       DE - DE + 19
    EXTERN date_to_ascii


    ; Convert a 32-bit value to a ASCII (%x format)
    ; Parameters:
    ;       HL - Pointer to a 32-bit value, little-endian
    ;       DE - String destination. It must have at least 8 free bytes to write the ASCII result.
    ; Returns:
    ;       HL - HL + 4
    ;       DE - DE + 8
    ; Alters:
    ;       A, DE, HL
    EXTERN dword_to_ascii


    ; Convert a 32-bit unsigned value to ASCII (%u format)
    ; Parameters:
    ;       HL - pointer to 32 bit value in little endian (source)
    ;       DE - String destination. It must have 10 free bytes to write the ASCII result.
    ; Returns:
    ;       DE - DE + 10
    ;       HL - HL + 4
    ; Alters:
    ;       A, DE, HL, contents of original 32 bit value now zero.
    EXTERN dword_to_ascii_dec


    ; Check if character in A is a letter [A-Za-z]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not an alpha char
    ;   not carry flag - Is an alpha char
    EXTERN is_alpha


    ; Check if character in A is alpha numeric [A-Za-z0-9]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not an alpha numeric
    ;   not carry flag - Is an alpha numeric
    EXTERN is_alpha_numeric


    ; Check if character in A is a decimal digit [0-9]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not a digit
    ;   not carry flag - Is a digit
    EXTERN is_dec_digit


    ; Check if character in A is a hex digit [0-9a-fA-F]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not a hex digit
    ;   not carry flag - Is a hex digit
    EXTERN is_hex_digit


    ; Check if character in A is a lower case letter [a-z]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not a lower char
    ;   not carry flag - Is a lower char
    EXTERN is_lower


    ; Check if character in A is printable
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not printable char
    ;   not carry flag - Is a printable char
    EXTERN is_print


    ; Check if character in A is an upper case letter [A-Z]
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not an upper char
    ;   not carry flag - Is an upper char
    EXTERN is_upper


    ; Check if character in A is a whitespace
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   carry flag - Not a whitespace
    ;   not carry flag - Is a whitespace
    EXTERN is_whitespace


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
    EXTERN memrep


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
    EXTERN memsep


    ; Initialize the memory pointed by HL with the byte given in E.
    ; Parameters:
    ;       HL - Memory address to initialize
    ;       BC - Size of the memory to initialize
    ;       E  - Byte to initialize the memory with
    EXTERN memset

    ; Convert an ASCII character representing a decimal digit to its binary value
    ; Parameters:
    ;  A - ASCII character to convert
    ; Returns:
    ;  A - Value on success (carry clear)
    ;      Preserved on failure (carry set)
    EXTERN parse_dec_digit


    ; Convert an ASCII character representing a hex digit to its binary value
    ; Parameters:
    ;  A - ASCII character to convert
    ; Returns:
    ;  A - Value on success (carry clear)
    ;      Preserved on failure (carry set)
    EXTERN parse_hex_digit


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
    EXTERN parse_int


    ; Look for a character in a NULL-terminated string
    ; Parameter:
    ;   HL - Source string address, must NOT be NULL
    ;   A  - Delimiter
    ; Returns:
    ;   A  - Delimiter if found, 0 if not found
    ;   HL - Address of the delimiter byte if found, or NULL byte if not found
    ; Alters:
    ;   A, HL
    EXTERN strchrnul


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
    EXTERN strcmp


    ; Function copying src string into dest, including the terminating null byte
    ; Parameters:
    ;   HL - source string
    ;   DE - destination string
    ; Alters
    ;   A
    EXTERN strcpy


    ; Routine returning the length of a NULL-terminated string
    ; Parameters:
    ;   HL - NULL-terminated string to get the length from
    ; Returns:
    ;   BC - Length of the string
    ; Alters:
    ;   A, BC
    EXTERN strlen


    ; Trim leading space character from a string pointed by HL
    ; Parameters:
    ;   HL - NULL-terminated string to trim leading spaces from
    ;   BC - Length of the string
    ; Returns:
    ;   HL - Address of the non-space character from the string
    ;   BC - Length of the remaining string
    ; Alters:
    ;   A
    EXTERN strltrim


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
    EXTERN strncat


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
    EXTERN strncmp


    ; Same as strcpy but if the source address is smaller than the given size,
    ; the destination buffer will be filled with NULL (\0) byte.
    ; Parameters:
    ;       HL - Source string address
    ;       DE - Destination string address
    ;       BC - Maximum number of bytes to write
    ; Alters:
    ;       A
    EXTERN strncpy


    ; Trim trailing space character from a string pointed by HL
    ; Parameters:
    ;   HL - String to trim leading spaces from
    ;   BC - Length of the string
    ; Returns:
    ;   HL - Address of the non-space character from the string
    ;   BC - Length of the remaining string
    ; Alters:
    ;   A
    EXTERN strrtrim


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
    EXTERN strsep


    ; Convert all characters of the given string to lowercase
    ; Parameters:
    ;       HL - Address of the string to convert
    ; Alters:
    ;       A
    EXTERN strtolower


    ; Convert all characters of the given string to uppercase
    ; Parameters:
    ;       HL - Address of the string to convert
    ; Alters:
    ;       A
    EXTERN strtoupper


    ; Subroutine converting a character to a lower case
    ; Parameters:
    ;   A - ASCII character
    ; Returns:
    ;   A - Lower case character on success, same character else
    EXTERN to_lower


    ; Convert an ASCII character to upper case
    ; Parameter:
    ;   A - ASCII character
    ; Returns:
    ;   A - Upper case character on success, same character else
    ;   carry flag - Invalid parameter
    ;   not carry flag - Success
    EXTERN to_upper

    ENDIF