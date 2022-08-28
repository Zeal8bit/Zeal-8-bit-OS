; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        IFNDEF STRUTILS_H
        DEFINE STRUTILS_H

        ; Public routines. The descriptions are given in the implementation file.
        EXTERN strltrim
        EXTERN strrtrim
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