        INCLUDE "errors_h.asm"
        INCLUDE "osconfig.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "log_h.asm"

        EXTERN _zos_kernel_sp
        EXTERN zos_vfs_open_internal
        EXTERN zos_vfs_read_internal
        EXTERN zos_vfs_dstat_internal

        DEFC TWO_PAGES_SIZE_UPPER_BYTE = (MMU_VIRT_PAGES_SIZE >> 8) * 2

        SECTION KERNEL_TEXT

        ; Load binary file which is pointed by HL
        ; Parameters:
        ;       HL - Absolute path to the file
        ; This routine never returns as it executes the laoded file
        PUBLIC zos_load_file
zos_load_file:
        ; Store current file name
        ld (_cur_file_name), hl
        ; Put the file path in BC
        ld b, h
        ld c, l
        ; Set flags to read-only
        ld h, O_RDONLY
        ; HL is preserved
        call zos_vfs_open_internal
        ; File descriptor in A
        ; Error if the descriptor is less than 0
        or a
        jp m, _zos_load_failed
        ; No error, let's check the file size, it must not exceed 48KB
        ; (the system is is the first bank, so we have 3 free banks)
        ld de, _file_stats
        ld h, a
        call zos_vfs_dstat_internal
        ; H still contains dev number, DE contains the status structure address.
        ; Put the structure address in HL instead and so the dev number will be in D
        ex de, hl 
        ; Check if an error occured while getting the info
        or a
        jp nz, _zos_load_failed
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
        jp z, _zos_load_failed
        ; Check that B, the 2nd lowest byte is less or equal to 0x80, if that's not the case,
        ; it means that the file is bigger than 32K.
        ld a, b
        ; Optimize a bit, we make the assumption that pages are always 8-bit aligned
        cp TWO_PAGES_SIZE_UPPER_BYTE
        jp nc, _zos_load_failed ; File size must not exceed 32K, so the highest bytes must be 0
        ; check that the upper bytes are 0
        ld a, (hl)
        inc hl
        or (hl)
        jp nz, _zos_load_failed
        ; BC contains the size of the file to copy, D contains the dev number.
        ; HL can be altered, it won't be used anymore
        ; Before that, we have to check how many `read` calls we'll need to make:
        ;       - If size is > 16KB, we will need 2 calls
        ;       - Else, we will need 1 call
        xor a
        ld hl, MMU_VIRT_PAGES_SIZE
        sbc hl, bc
        jp nc, _zos_load_one_call      ; 1 call as BC is <= HL
        ; Only support program loading on 0x4000 at the moment
        ASSERT(CONFIG_KERNEL_INIT_EXECUTABLE_ADDR == 0x4000)
        ASSERT(MMU_PAGE1_VIRT_ADDR == 0x4000) 
        ; Map two RAM pages to page1 and page2
        MMU_MAP_VIRT_FROM_PHYS(MMU_PAGE_1, MMU_USER_PHYS_START_PAGE)
        MMU_MAP_VIRT_FROM_PHYS(MMU_PAGE_2, MMU_USER_PHYS_START_PAGE + 1)
        ; First call to read
        push bc
        ld bc, MMU_VIRT_PAGES_SIZE
        ld h, d
        ld de, MMU_PAGE1_VIRT_ADDR
        call zos_vfs_read_internal
        ; Check A for any error
        or a
        jp nz, _zos_load_failed_with_pop
        ; BC should be 0 here
        or b
        or c
        ; TODO: MAKE A LOOP IF BC IS NOT 0
        jp nz, _zos_load_failed_with_pop
        ; HL has been restored from the stack already, so H contains the dev number still
        ; BC contains the number of bytes read from the file
        ; DE can be altered, we are going to use HL to calculate the number of bytes remaining
        ld d, h
        pop hl  ; Pop previously pushed bc, containing the whole buffer size, into hl
        ; Carry is set to 0 as A is 0 already
        ld bc, MMU_VIRT_PAGES_SIZE
        sbc hl, bc
        ; HL contains the remaining bytes to write, put that in BC for the next call
        ld b, h
        ld c, l
        ; Prepare H with the dev number
        ld h, d
        ld de, MMU_PAGE2_VIRT_ADDR
        call zos_vfs_read_internal
        or a
        jp nz, _zos_load_failed 
        or b
        or c
        jp nz, _zos_load_failed ; size must be 0 now!
        ; Success, we can now execute the program
        ; Save the kernel stack and set the user's stack pointer
        ld (_zos_kernel_sp), sp
        ld sp, CONFIG_KERNEL_STACK_ADDR ; Save address as the kernel
        ; ============================================================================== ;
        ; KERNEL STACK CANNOT BE ACCESSED ANYMORE FROM NOW ON, JUST JUMP TO THE USER CODE!
        ; ============================================================================== ;
        MMU_MAP_VIRT_FROM_PHYS(MMU_PAGE_3, MMU_USER_PHYS_START_PAGE + 2)
        jp CONFIG_KERNEL_INIT_EXECUTABLE_ADDR
_zos_load_one_call:
        ; Map two RAM pages to page1 and page2
        MMU_MAP_VIRT_FROM_PHYS(MMU_PAGE_1, MMU_USER_PHYS_START_PAGE)
        MMU_MAP_VIRT_FROM_PHYS(MMU_PAGE_2, MMU_USER_PHYS_START_PAGE + 1)
        ; Put the dev in H
        ld h, d
        ; Destination buffer is first page, in DE
        ld de, MMU_PAGE1_VIRT_ADDR
        ; Push HL as required by VFS routines
        push bc
        call zos_vfs_read_internal
        or a
        jp nz, _zos_load_failed
        ; Check that BC is equal to the initial value
        ; TODO: loop until BC is 0
        ; Save the opened dev in D
        ld d, h
        xor a
        pop hl
        sbc hl, bc
        jp nz, _zos_load_failed
        ; Close the dev, no need to check the return value
        ld h, d
        call zos_vfs_close
        ; Save the kernel stack and set the user's stack pointer
        ld (_zos_kernel_sp), sp
        ld sp, CONFIG_KERNEL_STACK_ADDR ; Save address as the kernel
        ; ============================================================================== ;
        ; KERNEL STACK CANNOT BE ACCESSED ANYMORE FROM NOW ON, JUST JUMP TO THE USER CODE!
        ; ============================================================================== ;
        MMU_MAP_VIRT_FROM_PHYS(MMU_PAGE_3, MMU_USER_PHYS_START_PAGE + 2)
        ; Execute the init program in RAM
        jp CONFIG_KERNEL_INIT_EXECUTABLE_ADDR

_zos_load_failed_with_pop:
        pop hl
_zos_load_failed:
        ; Save A for code error?
        ld hl, _load_error_1
        call zos_log_error
        xor a
        ld hl, (_cur_file_name)
        call zos_log_message
        xor a
        ld hl, _load_error_2
        call zos_log_message
_loop:  halt
        jp _loop

        ; TODO: Syscall exec
        PUBLIC zos_loader_exec
zos_loader_exec:
        ld a, ERR_NOT_IMPLEMENTED
        ret

        ; TODO: Syscall exit
        PUBLIC zos_loader_exit
zos_loader_exit:
        ld a, ERR_NOT_IMPLEMENTED
        ret


_load_error_1: DEFM "Could not load ", 0
_load_error_2: DEFM " initialization file\n", 0

        SECTION KERNEL_BSS
_file_stats: DEFS STAT_STRUCT_SIZE
_cur_file_name: DEFS 2