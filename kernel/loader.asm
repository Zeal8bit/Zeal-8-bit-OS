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

        ; Let's allocate at most 3 pages for a single program (48KB)
        DEFC KERNEL_PAGES_PER_PROGRAM    = 3
        DEFC KERNEL_STACK_ENTRY_SIZE     = KERNEL_PAGES_PER_PROGRAM + 2 ; 2 more bytes for Stack Pointer
        DEFC LOADER_OVERRIDE_PROGRAM     = 0
        DEFC LOADER_KEEP_PROGRAM_IN_MEM  = 1
        DEFC LOADER_BIN_MAX_SIZE         = 0xC000 ; (48KB)

        MACRO CURRENT_OWNER _
            ld a, (_stack_entries)
            inc a
        ENDM

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
        REPT KERNEL_PAGES_PER_PROGRAM
            ; MMU_ALLOC_PAGE must not alter DE pair
            MMU_ALLOC_PAGE()
            ; Allocated page is in B, check error first
            or a
            ret nz
            ld a, b
            ld (de), a
            inc de
            call _zos_page_set_current_owner
        ENDR
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
        ; Store dev number in D.
        pop de
        ; Check if an error occurred while getting the info
        or a
        jr nz, _zos_load_failed
        ; A is 0 if we reached here. The size is in little-endian!
        ; Make sure it doesn't exceed 48KB
        ld hl, (_file_stats + file_size_t + 2)
        ld a, h
        or l
        jr nz, _zos_load_too_big
        ld hl, (_file_stats + file_size_t)
        ; Optimize by only comparing the highest byte
        ld a, h
        cp LOADER_BIN_MAX_SIZE >> 8
        jr nc, _zos_load_too_big
        ; Check if the size is 0
        or l
        jr z, _zos_load_size_0
        ; Size is valid, store it in BC and return 0
        ld b, h
        ld c, l
        xor a
        ret
zos_load_and_open_error:
        neg
        ret
_zos_load_too_big:
        ld e, ERR_NO_MORE_MEMORY
        jr _zos_load_failed_close
_zos_load_size_0:
        ld e, ERR_ENTRY_CORRUPTED
        jr _zos_load_failed_close
_zos_load_failed:
        ld e, ERR_FAILURE
_zos_load_failed_close:
        ; Close the opened dev (in D register)
        ld h, d
        call zos_vfs_close
        ld a, e
        or a
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
        ; Reuse stat structure to fill the program parameters
        ld hl, CONFIG_KERNEL_STACK_ADDR
        ld (_file_stats), hl
        ld hl, 0
        ld (_file_stats + 2), hl
        ; Parameters:
        ;   D - Opened dev
        ;   BC - Size of the file
_zos_load_file_checked:
        ; BC contains the size of the file to copy, D contains the dev number.
        ; Only support program loading on 0x4000 at the moment
        ASSERT(CONFIG_KERNEL_INIT_EXECUTABLE_ADDR == 0x4000)
        ASSERT(KERN_MMU_PAGE1_VIRT_ADDR == 0x4000)
        ; Calculate the number of loops to do: (BC + 0x3FFF) / 0x4000
        ld hl, KERN_MMU_VIRT_PAGES_SIZE - 1
        add hl, bc
        ld a, h
        rlca
        rlca
        and 0x3
        ld b, a
        ; Prepare the file descriptor and destination buffer
        ld h, d
        ; DE will point to the allocated pages. All the pages will be
        ; allocated in virtual page 1 to simplify the code below.
        ld de, _allocate_pages
_zos_load_file_loop:
        ; Map the next page, the allocated pages are stored in DE
        ld a, (de)
        inc de
        MMU_SET_PAGE_NUMBER(MMU_PAGE_1)
        push bc
        push de
        push hl
        ld bc, KERN_MMU_VIRT_PAGES_SIZE
        ld de, KERN_MMU_PAGE1_VIRT_ADDR
        call zos_vfs_read_internal
        pop hl
        pop de
        pop bc
        ; Check A for any error
        or a
        jr nz, _zos_load_failed_h_dev
        djnz _zos_load_file_loop
        ; The program is ready, close the file as we don't need it anymore
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
        ; Map the user memory
        ld hl, (_allocate_pages)
        ld a, l
        MMU_SET_PAGE_NUMBER(MMU_PAGE_1)
        ld a, h
        MMU_SET_PAGE_NUMBER(MMU_PAGE_2)
        ld a, (_allocate_pages + 2)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_3)
        ; ============================================================================== ;
        ; KERNEL STACK CANNOT BE ACCESSED ANYMORE FROM NOW ON, JUST JUMP TO THE USER CODE!
        ; ============================================================================== ;
        jp CONFIG_KERNEL_INIT_EXECUTABLE_ADDR
_zos_load_failed_h_dev:
        ; Save the error value, DE and BC will be preserved
        ld d, a
        call zos_vfs_close
        ld a, d
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
zos_loader_exec_new_pages:
        ; DE and BC still contain the file to load and the string parameter,
        ; they won't be altered by the following call
        call zos_loader_allocate_user_pages
        jr nz, zos_loader_ret
        call zos_loader_exec_internal
        ; Returning from zos_loader_exec_internal means an error occurred, free the pages and return
        push af
        call zos_loader_free_user_pages
        pop af
        jr zos_loader_ret


        ; Override the current running program by loading a new one, whose name is in BC
        ; Parameters:
        ;   BC - File to load and execute
        ;   DE - String parameter, can be NULL
        ; Returns:
        ;   A - error code on failure, doesn't return on success
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
        ; Parameter was given, we have to copy it to the program stack
        ; D contains the opened dev, we should not alter it
        push de
        ; Save the size of the binary as we will need it later
        push bc
        ex de, hl
        call zos_sys_remap_de_page_2
        ex de, hl
        ; HL - String parameter
        call strlen
        ; TODO: Check if the size of the binary + the size of the parameters are bigger than 48KB?
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
        pop bc  ; Program size in BC
        pop de  ; D contains the opened dev
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
        ld hl, _stack_entries
        ld a, (hl)
        sub CONFIG_KERNEL_MAX_NESTED_PROGRAMS - 1
        jr z, zos_loader_allocate_user_pages_full
        push de
        push bc
        ; Update the current owner to simplify the code in `zos_load_allocate_page_to_de`
        inc (hl)
        ; Driectly allocate in `_allocate_pages` since we will use `_zos_user_page_1` to backup the current pages
        ld de, _allocate_pages
        call zos_load_allocate_page_to_de
        jr nz, zos_loader_allocate_user_pages_err
        ; Copy the current pages to the stack_head
        ld de, _zos_user_page_1
        ld hl, (_stack_head)
        ex de, hl
        REPT KERNEL_PAGES_PER_PROGRAM
            ldi
        ENDR
        ex de, hl
        ; Store the user stack too
        ld de, (_zos_user_sp)
        ld (hl), e
        inc hl
        ld (hl), d
        inc hl
        ; Update the top of the stack
        ld (_stack_head), hl
        ; Return success
        xor a
zos_loader_allocate_user_pages_ret:
        pop bc
        pop de
        ret
zos_loader_allocate_user_pages_err:
        ; Restore owner
        ld hl, _stack_entries
        dec (hl)
        jr zos_loader_allocate_user_pages_ret
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
        ; Current owner in A
        ld a, (hl)
        inc a
        ; Decrement owner
        dec (hl)
        ; Free the current user program's pages, browse the whole page owner array
        ; and look for all the apges allocated to the program
        ld b, MMU_RAM_PHYS_PAGES
        ld c, MMU_RAM_PHYS_START_IDX
        ld hl, _page_owners
_free_pages_loop:
        cp (hl)
        call z, free_page_c
        inc c
        inc hl
        djnz _free_pages_loop
        ; Pages have been freed and marked as not owned.
        ; Pop the current entry from the stack
        ld hl, (_stack_head)
        ld bc, -KERNEL_STACK_ENTRY_SIZE
        add hl, bc
        ; HL points to the previous entry's SPh, increment it to make it point to
        ; the value we just popped
        ld (_stack_head), hl
        ; Success
        xor a
        ret

        ; Make the page C, pointed by HL, free (not owned)
        ; Parameters:
        ;   HL - Address of page C int he owner array
        ;   C - Page index
        ; Returns:
        ;   [HL] - 0
        ; Alters:
        ;   None
free_page_c:
        push hl
        push bc
        push af
        ld (hl), 0
        ld a, c
        MMU_FREE_PAGE()
        pop af
        pop bc
        pop hl
        ret


        ; Get the owner address for the given page and return the current owner
        ; Parameters:
        ;   B - Page to get the owner address from
        ; Returns:
        ;   HL - Owner address
        ;   A - Current owner
        ; Alters:
        ;   A, HL, DE
_zos_page_owner_addr:
        ld d, 0
        ld e, b
        ; Page in B starts at MMU_RAM_PHYS_START_IDX, but we want pages to be indexed
        ; from 0, so subtract MMU_RAM_PHYS_START_IDX.
        ld hl, _page_owners - MMU_RAM_PHYS_START_IDX
        add hl, de
        CURRENT_OWNER()
        ret


        ; Mark the given page as owned byt he current program
        ; Parameters:
        ;   B - Page to get the owner address from
        ; Returns:
        ;   HL - Owner address
        ;   A - ERR_SUCCESS
        ; Alters:
        ;   A, HL
_zos_page_set_current_owner:
        push de
        call _zos_page_owner_addr
        ld (hl), a
        pop de
        xor a
        ret


        ; Allocate a page for the current user program.
        ; Parameters:
        ;   None
        ; Returns:
        ;   A - ERR_SUCCESS on success
        ;       ERR_NO_MORE_MEMORY if there is no more memory
        ;   B - Allocated page if A is ERR_SUCCESS
        PUBLIC zos_loader_palloc
zos_loader_palloc:
        MMU_ALLOC_PAGE()
        or a
        ret nz
        jp _zos_page_set_current_owner


        ; Free a previously allocated page.
        ; Parameters:
        ;   B - Page to free
        ; Returns:
        ;   A - ERR_SUCCESS on success
        ;       ERR_INVALID_PARAMETER if the page doesn't belong to the current program
        PUBLIC zos_loader_pfree
zos_loader_pfree:
        call _zos_page_owner_addr
        ; Make sure they are the same
        sub (hl)
        jr nz, _zos_loader_invalid_param
        ; Marke the page as free
        ld (hl), a
        ; Free the page in the MMU
        MMU_FREE_PAGE()
        ret
_zos_loader_invalid_param:
        ld a, ERR_INVALID_PARAMETER
        ret


        SECTION KERNEL_BSS
        ; Keep the owners of the pages allacoted via `palloc` in this array, this will simplify the code above
        ; compared to pushing the allocated pages on the `_stack_user_pages` stack. 0 means no owner. Some
        ; pages may be actually used, but the macro `MMU_ALLOC_PAGE` will simply never return themit, so it's
        ; safe to keep it as not owned.
_page_owners: DEFS MMU_RAM_PHYS_PAGES

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
