; SPDX-FileCopyrightText: 2023-2024 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    IFNDEF STRUTILS_H
    DEFINE STRUTILS_H

    DEFC FORMAT_SPECIFIER = 0x80
    DEFC FORMAT_SPECIFIER_MASK = 0xf

    ; Replace with 4 characters (char array)
    DEFC FORMAT_4_CHAR  = FORMAT_SPECIFIER | 0 | (4 << 4)
    DEFC FORMAT_STRING  = FORMAT_SPECIFIER | 1
    DEFC FORMAT_U8_HEX  = FORMAT_SPECIFIER | 2
    DEFC FORMAT_CHAR    = FORMAT_SPECIFIER | 3

    ; Public routines. The descriptions are given in the implementation file.
    EXTERN strformat
    EXTERN strltrim
    EXTERN strcmp
    EXTERN strchrnul
    EXTERN strncmp
    EXTERN memsep
    EXTERN strsep
    EXTERN strlen
    EXTERN strcpy
    EXTERN strcpy_unsaved
    EXTERN strncpy
    EXTERN strncat
    EXTERN strtolower
    EXTERN strtoupper
    EXTERN parse_int
    EXTERN parse_hex
    EXTERN parse_dec
    EXTERN is_print
    EXTERN is_alpha_numeric
    EXTERN is_digit
    EXTERN to_lower
    EXTERN to_upper
    EXTERN byte_to_ascii

    ENDIF ; STRUTILS_H