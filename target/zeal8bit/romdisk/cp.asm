; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "zos_sys.asm"

    SECTION TEXT

    EXTERN error_print
    EXTERN init_static_buffer
    EXTERN init_static_buffer_end
    DEFC STATIC_BUFFER = init_static_buffer
    DEFC STATIC_BUFFER_SIZE = init_static_buffer_end - init_static_buffer

    ; "cp" command main function
    ; Parameters:
    ;       HL - ARGV
    ;       BC - ARGC
    ; Returns:
    ;       A - 0 on success
    PUBLIC cp_main
cp_main:
    ld a, c
    cp 3
    jp nz, _cp_usage
    ; Retrieve the filename given as a parameter
    inc hl
    inc hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a
    ex de, hl
    ; Source in HL, destination in DE. Start by opening the source file
    ld b, h
    ld c, l
    ld h, O_RDONLY
    OPEN()
    jp m, _cp_error
    ; DE was not modified by the syscall, save the source dev in D
    ld b, d
    ld c, e
    ld d, a
    ld h, O_WRONLY | O_CREAT | O_TRUNC
    OPEN()
    jp m, _cp_error_close
    ld e, a
    push de
_cp_loop:
    pop de
    push de
    ; Read from source file and write to destination file, until we don't have any bytes
    S_READ3(d, STATIC_BUFFER, STATIC_BUFFER_SIZE)
    or a
    jr nz, _cp_error_close_all
    ; Check if we there are no bytes to read anymore
    ld a, b
    or c
    jr z, _cp_end
    ; Get the destination descriptor back but keep it saved
    pop de
    push de
    ; BC already contains the number of bytes to write
    S_WRITE2(e, STATIC_BUFFER)
    ; In theory we should check that we wrote the same amount of bytes, but for
    ; simplicity reasons, let's only check for errors
    or a
    jr nz, _cp_error_close_all
    jp _cp_loop
_cp_end:
    ; Close the opened descriptors
    pop de
    ld h, d
    CLOSE()
    ld h, e
    CLOSE()
    xor a   ; Success
    ret

_cp_usage:
    S_WRITE3(DEV_STDOUT, str_usage, str_usage_end - str_usage)
    ld a, 1
    ret

_cp_error_close_all:
    pop de
    ld b, a
    ld h, e
    CLOSE()
    ld a, b
    neg ; will be negated again before calling error_print
_cp_error_close:
    ; Save the current error in B
    ld b, a
    ; Close the source dev
    ld h, d
    CLOSE()
    ; Restore the original error code
    ld a, b
_cp_error:
    neg
    ld de, 0
    call error_print
    ld a, 2
    ret

str_usage: DEFM "usage: cp <src> <dst>\n"
str_usage_end:

