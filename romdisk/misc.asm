; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "zos_sys.asm"
    INCLUDE "zos_video.asm"

    EXTERN error_print

    SECTION TEXT

    ; "exec" command main function
    ; Parameters:
    ;       HL - ARGV
    ;       BC - ARGC
    ; Returns:
    ;       A - 0 on success
    PUBLIC exec_main
exec_main:
    ; Make sure there are exactly two parameters (ignore argc/v for the moment)
    ld a, c
    cp 2
    ret c
    ; Dereference filename and execute it
    inc hl
    inc hl
    ld c, (hl)
    inc hl
    ld b, (hl)
    inc hl
    ; Set ARGV to 0
    ld de, 0
    dec a
    dec a
    jr z, _exec_main_no_param
    ; We do have an extra parameter!
    ld e, (hl)
    inc hl
    ld d, (hl)
_exec_main_no_param:
    EXEC()
    ld de, 0
    jp error_print

    ; Reset the board
    PUBLIC reset_main
reset_main:
    rst 0


    ; Clear the screen with default color
    PUBLIC clear_main
clear_main:
    ; Use the "clear screen" IOCTL
    ld h, DEV_STDOUT
    ld c, CMD_CLEAR_SCREEN
    IOCTL()
    ret


