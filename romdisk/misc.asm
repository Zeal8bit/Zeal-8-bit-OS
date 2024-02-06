; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "zos_sys.asm"
    INCLUDE "zos_video.asm"

    EXTERN error_print
    EXTERN strlen

    SECTION TEXT

    ; "exec" command main function
    ; Parameters:
    ;       HL - ARGV
    ;       BC - ARGC
    ; Returns:
    ;       A - 0 on success
    PUBLIC exec_main
    PUBLIC exec_main_ret_success
exec_main:
    ; There must be at least two parameters
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
    jr z, exec_main_bc_de
    ; We do have an extra parameter!
    ld e, (hl)
    inc hl
    ld d, (hl)
    dec a
    jr z, exec_main_bc_de
    ; If we still have parameters, we have to "merge" them, as required by
    ; the EXEC syscall. DE is the start of the real parameter, browse it
    ; and replace all the '\0' by ' ', we should have A (reg) null-bytes
    ld h, d
    ld l, e
    push bc
    ld b, a
    xor a
_exec_main_merge:
    inc hl
    cp (hl)
    jr nz, _exec_main_merge
    ; Found a NULL-byte!
    ld (hl), ' '
    djnz _exec_main_merge
    pop bc

    ; Execute the program stored in BC with the parameters in DE
    PUBLIC exec_main_bc_de
exec_main_bc_de:
    ld h, EXEC_PRESERVE_PROGRAM
    ; Keep the file name so that we can show it in case of error
    push bc
    EXEC()
    pop hl
    ; If an error occurred while executing, A will not be 0
    or a
    jr nz, exec_main_error
exec_main_ret_success:
    ; Exec was a success, the returned value from sub-process is in D
    ld a, d
    ld (exec_sub_program_ret), a
    ret
exec_main_error:
    ; Do not alter the error to print
    ld d, a
    ; Get the length of the command (in HL)
    call strlen
    ld a, d
    ; Prepare the error_print parameter
    ld d, h
    ld e, l
    ; Append ": " at the end of the file name
    add hl, bc
    ld (hl), ':'
    inc hl
    ld (hl), ' '
    inc bc
    inc bc
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


    SECTION DATA
    PUBLIC exec_sub_program_ret
exec_sub_program_ret: DEFS 1