; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "zos_sys.asm"

        SECTION TEXT

        EXTERN error_print

        MACRO ERR_CHECK goto_label
                or a
                jp nz, goto_label
        ENDM

        ; "cd" command main function
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        PUBLIC cd_main
cd_main:
        ; Check that argc is 2 (command itself is part of argc)
        ld a, c
        cp 2
        jp nz, _cd_usage
        ; Retrieve the filename given as a parameter
        inc hl
        inc hl  ; skip the first pointer
        ld e, (hl)
        inc hl
        ld d, (hl)
        ; Path to the new dir in DE
        CHDIR()
        ERR_CHECK(_cd_error)
        ret

_cd_usage:
        S_WRITE3(DEV_STDOUT, str_usage, str_usage_end - str_usage)
        ld a, 1
        ret

_cd_error:
        ; Give NULL to error_print to have a default error message
        ld de, 0
        call error_print
        ld a, 2
        ret


str_usage: DEFM "usage: cd <path_to_dir>\n"
str_usage_end:
