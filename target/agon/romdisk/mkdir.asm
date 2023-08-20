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

        ; "mkdir" command main function
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        PUBLIC mkdir_main
mkdir_main:
        ; Check that argc is 2 (command itself is part of argc)
        ld a, c
        cp 2
        jp nz, _mkdir_usage
        ; Retrieve the filename given as a parameter
        inc hl
        inc hl  ; skip the first pointer
        ld e, (hl)
        inc hl
        ld d, (hl)
        ; Path to the new dir in DE
        MKDIR()
        ERR_CHECK(_mkdir_error)
        ret

_mkdir_usage:
        S_WRITE3(DEV_STDOUT, str_usage, str_usage_end - str_usage)
        ld a, 1
        ret

_mkdir_error:
        ld de, 0
        call error_print
        ld a, 2
        ret


str_usage: DEFM "usage: mkdir <path_to_dir>\n"
str_usage_end:
