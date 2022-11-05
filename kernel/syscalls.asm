; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
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
        MMU_GET_PAGE_INDEX_FROM_VIRT_ADDRESS(D, E)
        ; If the destination address is the first page (where the current code lies), return
        ; an error
        or a
        jr z, _zos_sys_map_error
        ; Pass the 24-bit address to the MMU.
        ; Can only alter A, but can use the stack to save other registers.
        MMU_MAP_PHYS_HBC_TO_PAGE_A()
        ret
_zos_sys_map_error:
        ld a, ERR_INVALID_VIRT_PAGE
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
        ; Here, we cannot use kernel RAM, nor the kernel stack as the kernel RAM has not been
        ; mapped yet.
        ; A contains the user's mapped page, we need it when the kernel stack is mapped,
        ; as it is required to restore the page, so save HL (on the user stack) and
        ; use HL to store A.
        ; NOTE: it would have been possible to use alternate register to save the 
        ;       user's RAM page. However, the kernel is interrupt agnostic in the sense
        ;       that it doesn't need interrupt to work. Moreover, using it would
        ;       require instructions "di" and "ei", This would give something like:
        ;       di
        ;       ex af,af'
        ;       <Map kernel RAM>
        ;       ei
        ;       But what if interrupts where disabled by the user when syscall was called?
        ;       This snippet of code would re-enable interrupts!
        push hl ; A may contain a parameter (for seek), use HL to save A
        ld h, a
        ; Just before performing the "normal" syscall process, check if the call is MAP
        ; In fact, MAP must not modify any other MMU page than the ones given as a 
        ; parameter. Then, let's check it now.
        ld a, l
        cp SYSCALL_MAP_NUMBER
        jp z, SYSCALL_MAP_ROUTINE
        ; Check if the syscall is even correct
        cp SYSCALL_COUNT
        jp nc, _zos_sys_invalid_syscall
        ; The syscall to execute is not MAP, continue the normal process.
        ; Map the kernel RAM to the kernel RAM to the second page (and not third), as such
        ; We will have access to both the user's stack and the kernel stack
        ; TODO: Document the fact that user's stack needs to be in the last page (same as kernel page)
        ; Get the hardware page MMU_PAGE_2 number in A, save it in L
        MMU_GET_PAGE_NUMBER(MMU_PAGE_2)
        ld l, a
        ; Map the kernel RAM to the second page now.
        MMU_MAP_VIRT_FROM_PHYS(MMU_PAGE_2, MMU_KERNEL_PHYS_PAGE)
        ; Both the kernel RAM and the user's RAM (stack) are available. HOWEVER, any kernel RAM operation
        ; needs to be accompagnied by an offset, as it not mapped where it should be (page 3).
        ld a, h
        ld (_zos_user_a - MMU_VIRT_PAGES_SIZE), a       ; Save original A parameter from the user
        ; Get and save the last page number too as this is where the kernel RAM will be mapped
        MMU_GET_PAGE_NUMBER(MMU_PAGE_3)
        ld (_zos_user_page_3 - MMU_VIRT_PAGES_SIZE), a
        ; Let's save page 1 here, it may be useful
        MMU_GET_PAGE_NUMBER(MMU_PAGE_1)
        ld (_zos_user_page_1 - MMU_VIRT_PAGES_SIZE), a
        ; Restore the original page 2 (but save it still in kernel RAM)
        ld a, l
        ld (_zos_user_page_2 - MMU_VIRT_PAGES_SIZE), a
        MMU_SET_PAGE_NUMBER(MMU_PAGE_2)
        ; Retrieve the original HL, but keep it on the stack. Map the kernel RAM in the last virtual page.
        pop hl
        push hl
        MMU_MAP_VIRT_FROM_PHYS(MMU_PAGE_3, MMU_KERNEL_PHYS_PAGE)
        ; We still cannot use the stack. The stack pointer register corresponds
        ; to the user's stack, not the system's.
        ld (_zos_user_sp), sp
        ; Load the system stack
        ld sp, CONFIG_KERNEL_STACK_ADDR
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
        ; Set the syscall flag to 1 to mark the fact that the following calls
        ; will result in returning to the user mode at last
        ld a, 1
        ld (_zos_syscall_ongoing), a
        ; Prepare the parameters before calling the syscall
        pop hl
        ld a, (_zos_user_a)
        call _zos_sys_jump
        ; Use HL to restore the syscall flag
        ld hl, (_zos_syscall_ongoing)
        ld (hl), 0
        ; Restore the user's stack pointer before setting its page
        ld sp, (_zos_user_sp)
        ; Keep the return value in H, we can do this because HL is never a return register
        ld h, a
        ; Restore back all the user's virtual pages
        ld a, (_zos_user_page_1)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_1)
        ld a, (_zos_user_page_2)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_2)
        ld a, (_zos_user_page_3)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_3)
        ; Restore return value in A, restore HL and exit
        ld a, h
        pop hl
        ret
_zos_sys_invalid_syscall:
        ld a, ERR_INVALID_SYSCALL
        pop hl
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
        ld a, b
        ; In practice the pages are (at least) aligned on 8-bit, no need for
        ; the lowest byte.
        MMU_GET_PAGE_INDEX_FROM_VIRT_ADDRESS(A, A)
        cp 3
        ret nz
        ; TODO: Have an API for this (BC - PAGE_SIZE)
        res 6, b        ; BC - 16KB
        jr zos_sys_remap_page_2
zos_sys_remap_de_page_2:
        ld a, d
        ; In practice the pages are (at least) aligned on 8-bit, no need for
        ; the lowest byte.
        MMU_GET_PAGE_INDEX_FROM_VIRT_ADDRESS(A, A)
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
        ; Get the page index to where DE is located
        MMU_GET_PAGE_INDEX_FROM_VIRT_ADDRESS(D, E)
        ; Result is in A
        or a
        ; If the page it is mapped to is 0, then we won't remap it
        ; because it means the kernel is trying to print something.
        ret z
        dec a
        jp z, _zos_sys_reserve_page_remap_1
        ; No remap necessary as DE is in page of index 2 (HL is 0 already)
        ; or page index 3. Let's assume that, in that case, it's a kernel
        ; address, so no need to remap.
        xor a
        ret
_zos_sys_reserve_page_invalid:
        ld a, ERR_INVALID_VIRT_PAGE
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
        ; If context is NULL, no changes occured
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
_zos_user_sp: DEFS 2
_zos_user_a:  DEFS 1
_zos_user_page_1: DEFS 1
_zos_user_page_2: DEFS 1
_zos_user_page_3: DEFS 1
        ; The following flag marks whether a syscall is in progress.
_zos_syscall_ongoing: DEFS 1
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
zos_syscalls_table_end:
