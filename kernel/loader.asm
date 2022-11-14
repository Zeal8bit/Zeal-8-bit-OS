; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "errors_h.asm"
        INCLUDE "osconfig.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "log_h.asm"
        INCLUDE "target_h.asm"

        EXTERN zos_vfs_open_internal
        EXTERN zos_vfs_read_internal
        EXTERN zos_vfs_dstat_internal
        EXTERN zos_sys_remap_bc_page_2
        EXTERN _zos_default_init

        DEFC TWO_PAGES_SIZE_UPPER_BYTE = (MMU_VIRT_PAGES_SIZE >> 8) * 2

        SECTION KERNEL_TEXT

        ; Load the first binary in the system
        ; Parameters:
        ;   HL - Absolute path to the file
        ; Returns:
        ;   A - error code on failure, doesn't return on success
        PUBLIC zos_load_init_file
zos_load_init_file:
        push hl ; Save file name
        ; Start by allocating 3 pages that will be used to store the user program.
        ; TODO: Once executer-program save is supported, it will be required to
        ;       allocate pages for the init program and save it in an array.
        REPTI index, 0, 1, 2
            MMU_ALLOC_PAGE()
            ; Allocated page is in B, check error first
            or a
            jr nz, zos_load_init_file_error
            ld a, b
            ld (_allocate_pages + index), a
        ENDR
        ; Tail-call to zos_load_file
        pop hl
        jp zos_load_file
zos_load_init_file_error:
        pop hl
        ret

        ; Load binary file which is pointed by HL
        ; Parameters:
        ;   HL - Absolute path to the file
        ; Returns:
        ;   A - error code on failure, doesn't return on success
        PUBLIC zos_load_file
zos_load_file:
        ; Put the file path in BC
        ld b, h
        ld c, l
        ; Set flags to read-only
        ld h, O_RDONLY
        call zos_vfs_open_internal
        ; File descriptor in A
        ; Error if the descriptor is less than 0
        or a
        ret m
        ; No error, let's check the file size, it must not exceed 48KB
        ; (the system is in the first bank, so we have 3 free banks)
        ld de, _file_stats
        ld h, a
        call zos_vfs_dstat_internal
        ; H still contains dev number, DE contains the status structure address.
        ; Put the structure address in HL instead and so the dev number will be in D
        ex de, hl 
        ; Check if an error occurred while getting the info
        or a
        ret nz
        ; Check the size field, if size field is not the first attribute, modify the code below
        ASSERT(file_size_t == 0)
        ; A is 0 if we reached here. The size is in little-endian!
        ld c, (hl)
        inc hl
        ld b, (hl)
        inc hl
        ; Check that the size is not 0
        ld a, b
        or c
        jr z, _zos_load_failed
        ; Check that B, the 2nd lowest byte is less or equal to 0x80, if that's not the case,
        ; it means that the file is bigger than 32K.
        ld a, b
        ; Optimize a bit, we make the assumption that pages are always 8-bit aligned
        cp TWO_PAGES_SIZE_UPPER_BYTE
        jr nc, _zos_load_failed ; File size must not exceed 32K, so the highest bytes must be 0
        ; check that the upper bytes are 0
        ld a, (hl)
        inc hl
        or (hl)
        jr nz, _zos_load_failed
        ; BC contains the size of the file to copy, D contains the dev number.
        ; Only support program loading on 0x4000 at the moment
        ASSERT(CONFIG_KERNEL_INIT_EXECUTABLE_ADDR == 0x4000)
        ASSERT(MMU_PAGE1_VIRT_ADDR == 0x4000)
        ; Map the user memory
        ld a, (_allocate_pages)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_1)
        ld a, (_allocate_pages + 1)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_2)
        ; Perform a read of a page size until we read less bytes than than MMU_VIRT_PAGES_SIZE
        push bc
        ld bc, MMU_VIRT_PAGES_SIZE
        ld h, d
        ld de, MMU_PAGE1_VIRT_ADDR
        call zos_vfs_read_internal
        ; In any case, pop the file size in DE
        pop de
        ; Check A for any error
        or a
        ret nz
        ; Check if we still have data to read
        ex de, hl
        ; HL now contains the file size, D contains the opened dev.
        ; Calculate Remaining size = file size - bytes read
        sbc hl, bc
        ; HL contains the remaining size, if we still have bytes, read again.
        jp z, _zos_load_read_finish
        ld b, h
        ld c, l
        ld h, d
        ld de, MMU_PAGE2_VIRT_ADDR
        call zos_vfs_read_internal
        or a
        ret nz
_zos_load_read_finish:
        ; The stack may not be clean, but there is no need to pop the value as it won't be used:
        ; we are going to set the user stack and jump to the program.
        ; User program is loaded in RAM, allocate one last page for stack.
        ld a, (_allocate_pages + 2)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_3)
        ld sp, CONFIG_KERNEL_STACK_ADDR
        ; ============================================================================== ;
        ; KERNEL STACK CANNOT BE ACCESSED ANYMORE FROM NOW ON, JUST JUMP TO THE USER CODE!
        ; ============================================================================== ;
        jp CONFIG_KERNEL_INIT_EXECUTABLE_ADDR
_zos_load_failed:
        ld a, ERR_FAILURE
        ret

        ; Load and execute a program from a file name given as a parameter.
        ; The program will cover the current program.
        ; Parameters:
        ;       BC - File to load and execute
        ;       (B - Save the current program in RAM?)
        ; Returns:
        ;       A - Nothing on success, the new program is executed.
        ;           ERR_FAILURE on failure.
        ; Alters:
        ;       HL
        PUBLIC zos_loader_exec
zos_loader_exec:
        push bc
        call zos_sys_remap_bc_page_2
        call zos_loader_exec_internal
        pop bc
        ret
zos_loader_exec_internal:
        ; DE is reachable for sure here, put the filename in HL.
        ; In case of a success, the stack will be discarded as the SP value
        ; will be overwritten and the memory pages reused. This behavior will
        ; change when saving current program context will be supported.
        ld h, b
        ld l, c
        jp zos_load_file

        ; Exit the current process and load back the init.bin file
        ; Parameters:
        ;       C - Returned code (unused yet)
        ; Returns:
        ;       None
        PUBLIC zos_loader_exit
zos_loader_exit:
        call zos_vfs_clean
        IF CONFIG_KERNEL_EXIT_HOOK
        call target_exit
        ENDIF
        ; TODO: Once executer-program save is supported, it may be required to
        ;       free the allocated pages of the callee here, with something like:
        ; ld a, (_allocate_pages_<nb>)
        ; MMU_FREE_PAGE(a)
        ; Load the init file name
        ld hl, _zos_default_init
        jp zos_load_file

        SECTION KERNEL_BSS
        ; Memory to store the pages allocated for the user program.
_allocate_pages: DEFS 3
        ; Buffer used to get the stats of the file to load.
_file_stats: DEFS STAT_STRUCT_SIZE
