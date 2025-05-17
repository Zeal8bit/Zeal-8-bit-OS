; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "zos_sys.asm"
    INCLUDE "zos_video.asm"
    INCLUDE "strutils_h.asm"

    EXTERN error_print

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
    ; Fall-through

    ; Execute the program stored in BC with the parameters in DE
    PUBLIC exec_main_bc_de
exec_main_bc_de:
    ; Keep the file name so that we can show it in case of error
    push bc
    call try_exec_bc_de
    pop hl
    ; If an error occurred while executing, A will not be 0
    or a
    jr nz, exec_main_error
exec_main_ret_success:
    ; Exec was a success, the returned value from sub-process is in D
    ld a, d
    ld (exec_sub_program_ret), a
    or a
    ; Exit on success
    ret z
    call byte_to_ascii
    ld (exit_with_error_msg_param), de
    S_WRITE3(DEV_STDOUT, exit_with_error_msg, exit_with_error_msg_end - exit_with_error_msg)
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


exit_with_error_msg: DEFM "Exited with error $"
exit_with_error_msg_param: DEFS 2
exit_with_error_msg_nl: DEFM "\n"
exit_with_error_msg_end:

    ; Execute the program pointed by BC, this routien will automatically
    ; determine whether to override or preserve the current program, depending
    ; on the kernel configuration structure.
    ; Parameters:
    ;   BC - Program path/name
    ;   DE - Parameter (optional)
    PUBLIC try_exec_bc_de
try_exec_bc_de:
    ; Check if the kernel has MMU support, if that's the case, this init program can be
    ; preserved in memory while the subprogram executes.
    KERNEL_CONFIG(hl)
    inc hl  ; point to MMU capability
    ld a, (hl)
    ; Prepare parameter before testing the MMU capability
    ld h, EXEC_PRESERVE_PROGRAM
    or a    ; A = 0 <=> no MMU capability, cannot preserve
    jr nz, _process_command_exec
    ld h, EXEC_OVERRIDE_PROGRAM
_process_command_exec:
    EXEC()
    ret


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