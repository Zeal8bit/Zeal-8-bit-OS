; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "errors_h.asm"
        INCLUDE "osconfig.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "strutils_h.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "log_h.asm"
        INCLUDE "target_h.asm"

        EXTERN zos_vfs_open_internal
        EXTERN zos_vfs_read_internal
        EXTERN zos_vfs_dstat_internal
        EXTERN zos_sys_remap_bc_page_2
        EXTERN zos_sys_remap_de_page_2
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


        ; Routine helper to open and check the size of a file.
        ; If this routines returns success, then a load/exec of the file is possible
        ; Parameters:
        ;   BC - File path
        ; Returns:
        ;   A - 0 on success, error code else
        ;   Z flag - Set on success
        ;   BC - Size of the file
        ;   D - Dev of the opened file
_zos_load_open_and_check_size:
        ; Set flags to read-only
        ld h, O_RDONLY
        call zos_vfs_open_internal
        ; File descriptor in A, error if the descriptor is less than 0
        or a
        jp m, zos_load_and_open_error
        ; No error, let's check the file size, it must not exceed 48KB
        ; (the system is in the first bank, so we have 3 free banks)
        ld de, _file_stats
        ld h, a
        push hl
        call zos_vfs_dstat_internal
        ; Put the structure address in HL instead and store dev number in D.
        ld hl, _file_stats
        pop de
        ; Check if an error occurred while getting the info
        or a
        jr nz, _zos_load_failed
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
        ; Success, A already contains 0
        ret
zos_load_and_open_error:
        neg
        ret
_zos_load_failed:
        ; Close the opened dev (in D register)
        ld h, d
        call zos_vfs_close
        ld a, ERR_FAILURE
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
zos_load_file_bc:
        call _zos_load_open_and_check_size
        ret nz
        ; Reuse stat structure to fil the program parameters
        ld hl, CONFIG_KERNEL_STACK_ADDR
        ld (_file_stats), hl
        ld hl, 0
        ld (_file_stats + 2), hl
        ; Parameters:
        ;   D - Opened dev
        ;   BC - Size of the file
        ;   [SP] - Address of the parameter
        ;   [SP + 2] - Length of the parameter
_zos_load_file_checked:
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
        push hl
        call zos_vfs_read_internal
        pop hl
        ; In any case, pop the file size in DE
        pop de
        ; Check A for any error
        or a
        jr nz, _zos_load_failed_h_dev
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
        ; On error, close the opened file and return
        jp nz, _zos_load_failed_h_dev
        ; Put the opened dev in D again
        ld d, h
_zos_load_read_finish:
        ; The program is ready, close the file as we don't need it anymore
        ld h, d
        call zos_vfs_close
        ; Get the parameters out of the stack before mapping the user program stack
        ld hl, (_file_stats)
        ld sp, hl
        ; Put HL in DE
        ex de, hl
        ld bc, (_file_stats + 2)
        ; The stack may not be clean, but there is no need to pop the value as it won't be used:
        ; we are going to set the user stack and jump to the program.
        ; User program is loaded in RAM, allocate one last page for stack.
        ld a, (_allocate_pages + 2)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_3)
        ; ============================================================================== ;
        ; KERNEL STACK CANNOT BE ACCESSED ANYMORE FROM NOW ON, JUST JUMP TO THE USER CODE!
        ; ============================================================================== ;
        jp CONFIG_KERNEL_INIT_EXECUTABLE_ADDR
_zos_load_failed_h_dev:
        push af ; Save error value
        call zos_vfs_close
        pop af
        ; Pop the parameters out of the stack
        pop hl
        pop hl
        ret


        ; Load and execute a program from a file name given as a parameter.
        ; The program will cover the current program.
        ; Parameters:
        ;       BC - File to load and execute
        ;       DE - String parameter, can be NULL
        ;       (TODO: H - Save the current program in RAM?)
        ; Returns:
        ;       A - Nothing on success, the new program is executed.
        ;           ERR_FAILURE on failure.
        ; Alters:
        ;       HL
        PUBLIC zos_loader_exec
zos_loader_exec:
        push bc
        push de
        call zos_sys_remap_bc_page_2
        call zos_loader_exec_internal
        pop de
        pop bc
        ret
zos_loader_exec_internal:
        ld a, d
        or e
        jp z, zos_load_file_bc
        push de
        ; Check if the file is reachable and the size is correct
        call _zos_load_open_and_check_size
        ; Get back DE parameter but in HL
        pop hl
        ret nz
        ; Save the size of the binary as we will need it later
        push bc
        ; Parameter was given, we have to copy it to the program stack
        ; D contains the opened dev, we should not alter it
        push de
        ex de, hl
        call zos_sys_remap_de_page_2
        ex de, hl
        ; HL - String parameter
        call strlen
        ; Keep the size of the string, we will need to pass it to the program
        ASSERT(CONFIG_KERNEL_STACK_ADDR > 0xC000 && CONFIG_KERNEL_STACK_ADDR <= 0xFFFF)
        ; Calculate the address of destination: bottom_of_stack - parameter_length - 1
        ex de, hl   ; Switch the address of the parameter to DE again
        xor a
        ld hl, CONFIG_KERNEL_STACK_ADDR
        sbc hl, bc
        ex de, hl
        ; Re-use the file stat RAM area to store the parameters before remapping the last page
        inc bc
        ld (_file_stats), de
        ld (_file_stats + 2), bc
        ; Map the program at the same location as the Kernel RAM, DO NOT ACCESS RAM NOW
        ld a, (_allocate_pages + 2)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_3)
        ldir
        MMU_MAP_KERNEL_RAM(MMU_PAGE_3)
        ; The parameters to send to the program have already been saved,
        ; Clean our stack and execute the program
        pop de  ; D contains the opened dev
        pop bc  ; Program size in BC
        jp _zos_load_file_checked


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
