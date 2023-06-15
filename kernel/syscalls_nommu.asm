; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "osconfig.asm"
        INCLUDE "errors_h.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "time_h.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "syscalls_h.asm"

        EXTERN zos_loader_exit
        EXTERN zos_loader_exec

        SECTION SYSCALL_ROUTINES

        ; Initializer called at system startup, BSS is cleaned when called.
        PUBLIC zos_sys_init
zos_sys_init:
        ; Set up the beginning of the JP SYSCALL instruction, we have the high byte of SYSCALL address
        ; and the jp opcode: 0xC3.
        ld a, 0xc3
        ld (_zos_sys_jump), a
        ret

        ; Map a physical memory address to the virtual address space.
        ; Not supported on MMU-less targets.
        ; Returns:
        ;       A - ERR_NOT_SUPPORTED on success, error code else
zos_sys_map:
        ld a, ERR_NOT_SUPPORTED
        ret

        ; Routine that shall be called as soon as a syscall has been requested.
        ; It will map the kernel RAM before operating, then perform the syscall,
        ; and restore the user's RAM finally.
        ; Parameters:
        ;       None
        ; Alters:
        ;       A
        PUBLIC zos_sys_perform_syscall
zos_sys_perform_syscall:
        ; A may contain a parameter for seek syscall routine
        push af
        ; Check if the syscall is correct
        ld a, l
        cp SYSCALL_COUNT
        jr nc, _zos_sys_invalid_syscall
        ; Now we can prepare the jp SYSCALL instruction. Use the syscall tables to get the routine we have
        ; to jump to.
        push hl
        sla l
        ld h, zos_syscalls_table >> 8
        ; Put [HL] in HL and save it in the jump instruction code
        ld a, (hl)
        inc l
        ld h, (hl)
        ld l, a
        ld (_zos_sys_jump + 1), hl
        ; Prepare the parameters before calling the syscall
        pop hl
        pop af
        ; Save the user stack as we are going to switch to Kernel stack
        ld (_zos_user_sp), sp
        ld sp, CONFIG_KERNEL_STACK_ADDR
        ; We should not alter HL during a syscall, save it on the Kernel stack
        push hl
        call _zos_sys_jump
        ; Restore HL and user's stack pointer, A contains the return code
        pop hl
        ld sp, (_zos_user_sp)
        ret
_zos_sys_invalid_syscall:
        pop af
        ld a, ERR_INVALID_SYSCALL
        ret


        SECTION KERNEL_BSS
_zos_user_sp: DEFS 2
_zos_user_a:  DEFS 1
_zos_sys_jump: DEFS 3   ; Store jp nnnn instruction (3 bytes)

        SECTION SYSCALL_TABLE
        PUBLIC zos_syscalls_table
        ALIGN 0x100
zos_syscalls_table:
        DEFW zos_vfs_read
        DEFW zos_vfs_write
        DEFW zos_vfs_open
        DEFW zos_vfs_close
        DEFW zos_vfs_dstat
        DEFW zos_vfs_stat
        DEFW zos_vfs_seek
        DEFW zos_vfs_ioctl
        DEFW zos_vfs_mkdir
        DEFW zos_vfs_chdir
        DEFW zos_vfs_curdir
        DEFW zos_vfs_opendir
        DEFW zos_vfs_readdir
        DEFW zos_vfs_rm
        DEFW zos_vfs_mount
syscall_exit:
        DEFW zos_loader_exit
syscall_exec:
        DEFW zos_loader_exec
        DEFW zos_vfs_dup
        DEFW zos_time_msleep
        DEFW zos_time_settime
        DEFW zos_time_gettime
        DEFW zos_date_setdate
        DEFW zos_date_getdate
syscall_map:
        DEFW SYSCALL_MAP_ROUTINE
zos_syscalls_table_end:
