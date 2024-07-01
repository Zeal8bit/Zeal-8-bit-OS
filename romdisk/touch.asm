; SPDX-FileCopyrightText: Audrius Karabanovas <audrius@karabanovas.net>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "zos_sys.asm"

        SECTION TEXT

        EXTERN error_print

        MACRO ERR_CHECK goto_label
                or a
                jp nz, goto_label
        ENDM

        ; "touch" command main function
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        PUBLIC touch_main
touch_main:
        ; Check that argc is 2 (command itself is part of argc)
        ld a, c
        cp 2
        jp nz, _touch_usage
        ; Retrieve the filename given as a parameter
        inc hl
        inc hl  ; skip the first pointer
        ld c, (hl)
        inc hl
        ld b, (hl)
        ; Filepath in BC now, open the file
        ; BC - Path to file
        ; H - Flags
        ld h, O_WRONLY | O_CREAT | O_TRUNC
        OPEN()
        ERR_CHECK(_touch_error)
        CLOSE()
        xor a
        ret

_touch_usage:
        S_WRITE3(DEV_STDOUT, str_usage, str_usage_end - str_usage)
        ld a, 1
        ret

_touch_error:
        ld de, 0
        call error_print
        ld a, 2
        ret


str_usage: DEFM "usage: touch <path_to_file>\n"
str_usage_end:
