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
        EXTERN _zos_user_page_1
        EXTERN _zos_user_sp

        DEFC TWO_PAGES_SIZE_UPPER_BYTE = (KERN_MMU_VIRT_PAGES_SIZE >> 8) * 2

        ; Let's allocate at most 3 pages for a single program (48KB)
        DEFC KERNEL_PAGES_PER_PROGRAM    = 3
        DEFC KERNEL_STACK_ENTRY_SIZE     = KERNEL_PAGES_PER_PROGRAM + 2 ; 2 more bytes for Stack Pointer
        DEFC LOADER_OVERRIDE_PROGRAM     = 0
        DEFC LOADER_KEEP_PROGRAM_IN_MEM  = 1

        SECTION KERNEL_TEXT

        ; Load the first binary in the system
        ; Parameters:
        ;   HL - Absolute path to the file
        ; Returns:
        ;   A - error code on failure, doesn't return on success
        PUBLIC zos_load_init_file
zos_load_init_file:
        ; Save file name to open
        push hl
        ; Initialize the stack head, which is at the beginning of the array
        ld hl, _stack_user_pages
        ld (_stack_head), hl
        ; Start by allocating memory pages to store init program
        ld de, _allocate_pages
        call zos_load_allocate_page_to_de
        jr nz, zos_load_init_file_error
        ; Tail-call to zos_load_file
        pop hl
        jp zos_load_file
zos_load_init_file_error:
        pop hl
        ret


        ; Allocate KERNEL_PAGES_PER_PROGRAM pages while saving them to the array
        ; pointed by DE
        ; Parameters:
        ;   DE - Array to store the newly allocated pages
        ; Returns:
        ;   A - ERR_SUCCESS on success, error code else
        ;   Z flag - set if A is ERR_SUCCESS
        ; Alters:
        ;   A, BC, DE, HL
zos_load_allocate_page_to_de:
        REPT KERNEL_PAGES_PER_PROGRAM - 1
            ; MMU_ALLOC_PAGE must not alter DE pair
            MMU_ALLOC_PAGE()
            ; Allocated page is in B, check error first
            or a
            ret nz
            ld a, b
            ld (de), a
            inc de
        ENDR
        MMU_ALLOC_PAGE()
        ex de, hl
        ld (hl), b
        or a
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
        ASSERT(KERN_MMU_PAGE1_VIRT_ADDR == 0x4000)
        ; Map the user memory
        ld a, (_allocate_pages)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_1)
        ld a, (_allocate_pages + 1)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_2)
        ; Perform a read of a page size until we read less bytes than than KERN_MMU_VIRT_PAGES_SIZE
        push bc
        ld bc, KERN_MMU_VIRT_PAGES_SIZE
        ld h, d
        ld de, KERN_MMU_PAGE1_VIRT_ADDR
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
        ld de, KERN_MMU_PAGE2_VIRT_ADDR
        push hl
        call zos_vfs_read_internal
        pop hl
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
        ;       H  - Save the current program in RAM
        ;            0: Do not save, override the current program
        ;            1: Save the current program
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
        ; If H is LOADER_OVERRIDE_PROGRAM, no need to allocate memory pages
        ASSERT(LOADER_OVERRIDE_PROGRAM == 0)
        ld a, h
        or a
        jp nz, zos_loader_exec_new_pages
        ; Override the current program, no need to allocate pages
        call zos_loader_exec_internal
zos_loader_ret:
        pop de
        pop bc
        ret

        ; Jump to this branch if we need to allocate new memory pages to store
        ; the user program in.
        ; Parameters, Return and Alters is identical to `zos_loader_exec`
zos_loader_exec_new_pages:
        ; The top of the stack contains DE and BC registers
        call zos_loader_allocate_user_pages
        jr nz, zos_loader_ret
        call zos_loader_exec_internal
        ; Returning from zos_loader_exec_internal means an error occurred, free the pages and return
        push af
        call zos_loader_free_user_pages
        pop af
        jr zos_loader_ret

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
        ASSERT(CONFIG_KERNEL_STACK_ADDR > 0xC000 && CONFIG_KERNEL_STACK_ADDR <= 0xFFFF)
        ; Calculate the address of destination: bottom_of_stack - parameter_length - 1
        ex de, hl   ; Switch the address of the parameter to DE again
        xor a
        ld hl, CONFIG_KERNEL_STACK_ADDR
        sbc hl, bc
        ex de, hl
        ; Re-use the file stat RAM area to store the parameters before remapping the last page
        ld (_file_stats), de
        ld (_file_stats + 2), bc
        ; Map the program at the same location as the Kernel RAM, DO NOT ACCESS RAM NOW
        ld a, (_allocate_pages + 2)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_3)
        inc bc ; Copy NULL-byte too
        ldir
        MMU_MAP_KERNEL_RAM(MMU_PAGE_3)
        ; The parameters to send to the program have already been saved,
        ; Clean our stack and execute the program
        pop de  ; D contains the opened dev
        pop bc  ; Program size in BC
        jp _zos_load_file_checked


        ; Exit the current process and load back the init.bin file
        ; Parameters:
        ;   H - Return code
        ; Returns:
        ;   D - Return code (for the caller program)
        PUBLIC zos_loader_exit
zos_loader_exit:
    IF CONFIG_KERNEL_EXIT_HOOK
        ; target_exit must not alter H (return code)
        call target_exit
    ENDIF
        ; If the first program is exiting, reset the VFS and re-launch the init program
        ld a, (_stack_entries)
        or a
        jr z, zos_loader_exit_from_first
        ; TODO: Should we clean the VFS? Which descriptors? No way to differentiate between
        ; one opened by the callee-program and the caller-program
        ; Keep return code to pass it to the caller
        push hl
        ; Not exiting from the init program, pop the previous program
        call zos_loader_free_user_pages
        ; TODO: check the errors Should not occur, should be a dynamic assert
        ; Copy pages from _allocate_pages and user stack pointer into the syscall dispatcher
        ; HL points to the entry we just popped (previous program to load), copy it raw to _zos_user_page_1
        ; _zos_user_page_1 must be followed by _zos_user_page_2, _zos_user_page_3 AND _zos_user_sp!
        ld de, _zos_user_page_1
        ld bc, KERNEL_STACK_ENTRY_SIZE
        ldir
        ; Ready to jump back to the program, restore the return value in D(E)
        pop de
        ; Return ERR_SUCCESS
        xor a
        ret
zos_loader_exit_from_first:
        call zos_vfs_clean
        ; Load the init file name again
        ld hl, _zos_default_init
        jp zos_load_file


        ; Push the current pages to the stack and allocate new pages to _allocate_pages
        ; Parameters:
        ;   None
        ; Returns:
        ;   A - ERR_SUCCESS on success
        ;       ERR_CANNOT_REGISTER_MORE if the maximum amount of programs in RAM is reached
        ;       error code else
        ;   Z flag - Set if A is ERR_SUCCESS, not set else
        ; Alters:
        ;   A, HL
zos_loader_allocate_user_pages:
        ; Make sure we can still push programs to the stack
        ld a, (_stack_entries)
        sub CONFIG_KERNEL_MAX_NESTED_PROGRAMS - 1
        jr z, zos_loader_allocate_user_pages_full
        push de
        push bc
        ; Use _file_stats as a temporary buffer so that we don't erase _allocate_pages
        ; in case of any error
        ld de, _file_stats
        call zos_load_allocate_page_to_de
        jr nz, zos_loader_allocate_user_pages_ret
        ; Perform the following move: [_file_stats] -> [_allocate_pages] -> [_stack_head]
        ; where DE is _file_stats, BC is _allocate_pages and HL is _stack_head
        ld de, _file_stats
        ld hl, (_stack_head)
        ld bc, _allocate_pages
        REPT KERNEL_PAGES_PER_PROGRAM
            ld a, (bc)
            ld (hl), a
            ld a, (de)
            ld (bc), a
            inc hl
            inc de
            inc bc
        ENDR
        ; Store the user stack too
        ld de, (_zos_user_sp)
        ld (hl), e
        inc hl
        ld (hl), d
        inc hl
        ; Update the top of the stack
        ld (_stack_head), hl
        ; Update the number of entries
        ld hl, _stack_entries
        inc (hl)
        ; Return as a success
        xor a
zos_loader_allocate_user_pages_ret:
        pop bc
        pop de
        ret
zos_loader_allocate_user_pages_full:
        or ERR_CANNOT_REGISTER_MORE
        ret


        ; Pop the previous user pages from the stack into the _allocate_pages array
        ; Parameters:
        ;   None
        ; Returns:
        ;   HL - Points to the stack entry just removed, which contains: page1, page2, page3, SPl, SPh
        ;   A - ERR_SUCCESS on success
        ;       ERR_CANNOT_REGISTER_MORE if the stack is empty
        ; Alters:
        ;   A, BC, DE, HL
zos_loader_free_user_pages:
        ; Check that we have at least 1 entry on the stack
        ld hl, _stack_entries
        ld a, (hl)
        or a
        jr z, zos_loader_allocate_user_pages_full
        dec (hl)
        ; Free the current user program's pages
        ld de, _allocate_pages
        REPT KERNEL_PAGES_PER_PROGRAM - 1
            ld a, (de)
            MMU_FREE_PAGE()
            inc de
        ENDR
        ld a, (de)
        MMU_FREE_PAGE()
        ; Copy the top of the stack to _allocate_pages
        ld hl, (_stack_head)
        dec hl  ; Points to the user SP high byte
        dec hl
        dec hl
        ; Copy the previous user program's pages
        ; DE points to _allocate_pages + KERNEL_PAGES_PER_PROGRAM - 1
        REPT KERNEL_PAGES_PER_PROGRAM
            ldd
        ENDR
        ; HL points to the previous entry's SPh, increment it to make it point to
        ; the value we just popped
        inc hl
        ld (_stack_head), hl
        ; Success
        xor a
        ret


        SECTION KERNEL_BSS
        ; Small array to store freshly allocated user pages
        ; _allocate_pages[i] represents is page i + 1
        ; (page 0 is always the kernel)
_allocate_pages: DEFS KERNEL_PAGES_PER_PROGRAM

        ; Stack storing the pages allocated for the user programs that are waiting for
        ; another program to finish
        ASSERT(CONFIG_KERNEL_MAX_NESTED_PROGRAMS >= 1)
_stack_user_pages: DEFS (CONFIG_KERNEL_MAX_NESTED_PROGRAMS - 1) * KERNEL_STACK_ENTRY_SIZE
        ; Head address of the stack
_stack_head: DEFS 2
        ; Number of programs pushed to the stack ((_stack_head - _stack_user_pages) / KERNEL_STACK_ENTRY_SIZE)
_stack_entries: DEFS 1

        ; Buffer used to get the stats of the file to load.
_file_stats: DEFS STAT_STRUCT_SIZE
