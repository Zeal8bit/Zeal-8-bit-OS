; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "osconfig.asm"
        INCLUDE "errors_h.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "time_h.asm"
        INCLUDE "kern_mmu_h.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "syscalls_h.asm"

        EXTERN zos_loader_exit
        EXTERN zos_loader_exec
        EXTERN zos_loader_palloc
        EXTERN zos_loader_pfree

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
        ; Prerequisite:
        ;       [SP] - Backup of HL. Pop it from the stack at first to get H original value.
        ; Parameters:
        ;       DE - Destination address in virtual memory.
        ;            This will be rounded down to the target closest page bound.
        ;            For example, passing 0x5000 here, would in fact trigger a
        ;            remap of the page starting at 0x4000.
        ;       HBC - Upper 24-bits of the physical address to map.
        ;             For example, to map 0x10_0000, HBL must be equal to 0x1000.
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A
zos_sys_map:
        ; Get the register H value.
        pop hl
        ; Get the page index out of the virtual address pointed by DE
        KERNEL_MMU_PAGE_OF_VIRT_ADDR(D)
        ; If the destination address is the first page (where the current code lies), return
        ; an error. Z flag was set by the macro if A is 0.
        jr z, _zos_sys_map_error
        ; Pass the 24-bit address to the MMU.
        ; Can only alter A, but can use the stack to save other registers.
        MMU_MAP_PHYS_HBC_TO_PAGE_A()
        ret
_zos_sys_map_error:
        ld a, ERR_INVALID_VIRT_PAGE
        ret


        PUBLIC zos_sys_perform_syscall
zos_sys_perform_syscall:
        ex af, af'
        push af
        ld a, l
        cp SYSCALL_MAP_NUMBER
        jp z, SYSCALL_MAP_ROUTINE       ; restores AF and ex
        cp SYSCALL_COUNT
        jr nc, _zos_sys_invalid_syscall        ; restores AF and ex

        exx
        push hl ; User stack
        push de ; User stack
        push bc ; User stack
        ; Put the syscall in B
        ld b, a
        ; Get all MMU pages
        MMU_GET_PAGE_NUMBER(MMU_PAGE_1)
        ld e, a
        MMU_GET_PAGE_NUMBER(MMU_PAGE_2)
        ld d, a
        MMU_GET_PAGE_NUMBER(MMU_PAGE_3)
        ld c, a
        ; Kernel RAM is available after that!
        di
        MMU_MAP_KERNEL_RAM(MMU_PAGE_3)
        ld (_zos_user_sp), sp
        ld sp, CONFIG_KERNEL_STACK_ADDR
        ei
        
        ; We can freely use the register to calculate the syscall to jump to
        ld l, b
        sla l
        ld h, zos_syscalls_table >> 8
        ; Put [HL] in HL and save it in the jump instruction code
        ld a, (hl)
        inc l
        ld h, (hl)
        ld l, a
        ld (_zos_sys_jump + 1), hl
        ; Swap back the register to setup the parameters
        ex af, af'
        exx
        push hl ; HL is the only caller-saved pair
        call _zos_sys_jump
        pop hl
        ; Restore the alternate registers set before returning
        exx
        ex af, af'
        ; Restore user stack pointer
        ; MMU pages are in DE and C
        ld a, e
        MMU_SET_PAGE_NUMBER(MMU_PAGE_1)
        ld a, d
        MMU_SET_PAGE_NUMBER(MMU_PAGE_2)
        ld a, c
        di
        ld sp, (_zos_user_sp)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_3)
        ei
        ; User stack is restored
        pop bc
        pop de
        pop hl
        pop af
        ex af, af'
        exx
        ret
_zos_sys_invalid_syscall:
        pop af
        ex af, af'
        ld a, ERR_INVALID_SYSCALL
        ret

        ; Routine to remap a buffer from page 3 to page 2.
        ; This is handy if the user buffer is in the last page, but the kernel
        ; RAM is mapped at that spot.
        ; Parameters:
        ;       XY - Virtual address of the buffer to remap
        ; Returns:
        ;       XY - New address of the buffer if it was in page 3.
        ;            Unmodified if buffer not in page 3.
        PUBLIC zos_sys_remap_bc_page_2
        PUBLIC zos_sys_remap_de_page_2
zos_sys_remap_bc_page_2:
        ; In practice the pages are (at least) aligned on 8-bit, no need for
        ; the lowest byte.
        KERNEL_MMU_PAGE_OF_VIRT_ADDR(B)
        cp 3
        ret nz
        ; TODO: Have an API for this (BC - PAGE_SIZE)
        res 6, b        ; BC - 16KB
        jr zos_sys_remap_page_2
zos_sys_remap_de_page_2:
        KERNEL_MMU_PAGE_OF_VIRT_ADDR(D)
        cp 3
        ret nz
        ; TODO: Have an API for this (DE - PAGE_SIZE)
        res 6, d        ; DE - 16KB
        ; Map user's page 3 into page 2
zos_sys_remap_page_2:
        ld a, (_zos_user_page_3)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_2)
        ret

        ; Routine to remap user's page index 1 and 2.
        ; Parameters:
        ;       None
        ; Returns:
        ;       None
        ; Alters:
        ;       A
        PUBLIC zos_sys_remap_user_pages
zos_sys_remap_user_pages:
        ld a, (_zos_user_page_1)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_1)
        ld a, (_zos_user_page_2)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_2)
        ret

        ; Routine to map a buffer pointed by DE into any page except the page
        ; of index 1. This is handy for the drivers that need to map memory
        ; but don't know which page can be used.
        ; Parameters:
        ;       DE - Virtual address of the buffer to remap
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ;       HL - Context to pass back to zos_sys_restore_pages, necessary
        ;            to remap the pages correctly
        ; Alters:
        ;       A, HL
        PUBLIC zos_sys_reserve_page_1
zos_sys_reserve_page_1:
        ld hl, 0
        ; Get the page index where DE is located
        KERNEL_MMU_PAGE_OF_VIRT_ADDR(D)
        ; Result is in A, Z flag is set if A is 0.
        ; If the page it is mapped to is 0, then we won't remap it
        ; because DE is a kernel address.
        ret z
        dec a
        jp z, _zos_sys_reserve_page_remap_1
        ; No remap necessary as DE is in page of index 2 (HL is 0 already)
        ; or page index 3. Let's assume that, in that case, it's a kernel
        ; address, so no need to remap.
        xor a
        ret
_zos_sys_reserve_page_remap_1:
        ; The user buffer points to the page 1, which is the one we need to reserve
        ; Get the index of the page 2
        MMU_GET_PAGE_NUMBER(MMU_PAGE_2)
        ld l, a
        ; Get page 1 number to map it inside the second page
        MMU_GET_PAGE_NUMBER(MMU_PAGE_1)
        ld h, a
        MMU_SET_PAGE_NUMBER(MMU_PAGE_2)
        ; Make DE point to the page. If DE is 0x4000, it shall now be 0x8000.
        ; Upper two bits to modify
        ld a, d
        add 0x40
        ld d, a
        xor a   ; Success
        ret

        ; Counterpart of the routine above. This will restore the page 1 number
        ; to what it used to be before calling the routine zos_sys_reserve_page_1.
        ; Parameters:
        ;       HL - Context returned by the function above
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A
        PUBLIC zos_sys_restore_pages
zos_sys_restore_pages:
        ; If context is NULL, no changes occurred
        ld a, h
        or l
        ret z
        ; Else, restore the page 2 physical address
        ld a, l
        MMU_SET_PAGE_NUMBER(MMU_PAGE_2)
        ; Same for page 1
        ld a, h
        MMU_SET_PAGE_NUMBER(MMU_PAGE_1)
        xor a
        ret


        SECTION KERNEL_BSS

        PUBLIC _zos_user_sp
        PUBLIC _zos_user_page_1
_zos_user_a:  DEFS 1
_zos_user_page_1: DEFS 1
_zos_user_page_2: DEFS 1
_zos_user_page_3: DEFS 1
        ; SP address MUST follow the pages (check loader.asm)
_zos_user_sp: DEFS 2
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
        ; Keep a label on map syscall as it will be treated differently
        ; from other syscalls. In practice, we will not load the address
        ; from here. We will call the function directly.
syscall_map:
        DEFW SYSCALL_MAP_ROUTINE
        DEFW zos_vfs_swap
        DEFW zos_loader_palloc
        DEFW zos_loader_pfree
zos_syscalls_table_end:
