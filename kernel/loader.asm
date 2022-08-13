        INCLUDE "errors_h.asm"
        INCLUDE "osconfig.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "vfs_h.asm"

        EXTERN zos_log_error
        EXTERN zos_log_message
        EXTERN zos_vfs_dstat

        DEFC PAGE_SIZE = 16384

        SECTION KERNEL_TEXT

        ; Load binary file which is pointed by HL
        ; Parameters:
        ;       HL - Absolute path to the file
        ; This routine never returns as it executes the laoded file
        PUBLIC zos_load_file
        ; UT TODO:
        ;       - File not existing
        ;       - File bigger than 48K
        ;       - File exactly 48K
zos_load_file:
        ; Store current file name
        ld (_cur_file_name), hl
        ; Put the file path in DE
        ex de, hl
        ; Set flags to read-only
        ld h, O_RDONLY
        ; Push HL on the stack as VFS routines pop it at the end
        push hl
        call zos_vfs_open
        ; File descriptor in A
        ; Error if the descriptor is less than 0
        or a
        jp m, _zos_load_failed
        ; No error, let's check the file size, it must not exceed 48KB
        ; (the system is is the first bank, so we have 3 free banks)
        ld de, _file_stats
        ld h, a
        ; Push HL, as zos_vfs_* functions will pop HL at the end
        push hl
        call zos_vfs_dstat
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
        ; Check that B, the 2nd lowest byte is less or equal to 0xC0, if that's not the case,
        ; it means that the file is bigger than 48K.
        ld a, b
        cp 0xc0
        jp nz, _zos_load_failed ; File size must not exceed 48K, so the highest bytes must be 0
        ; check that the upper bytes are 0
        ld a, (hl)
        inc hl
        or (hl)
        jp nz, _zos_load_failed
        ; BC contains the size of the file to copy, D contains the dev number.
        ; HL can be altered, it won't be used anymore
        ; Before that, we have to check how many `read` calls we'll need to make:
        ;       - If size is > 32KB, we will need 2 calls
        ;       - Else, we will need 1 call
        xor a
        ld hl, 0x8000
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
        ld bc, 0x8000
        ld h, d
        ld de, MMU_PAGE1_VIRT_ADDR
        push hl
        call zos_vfs_read
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
        ld bc, 0x8000
        sbc hl, bc
        ; HL contains the remaining bytes to write, put that in BC for the next call
        ld b, h
        ld c, l
        ; Prepare H with the dev number and push it, as required by VFS routines
        ld h, d
        push hl
        ; Map the last program page
        MMU_MAP_VIRT_FROM_PHYS(MMU_PAGE_1, MMU_USER_PHYS_START_PAGE + 2)
        ld de, MMU_PAGE1_VIRT_ADDR
        call zos_vfs_read
        or a
        jp nz, _zos_load_failed 
        or b
        or c
        jp nz, _zos_load_failed ; size must be 0 now!
        ; Success, we can now execute the program
        ; Map the program correctly:
        MMU_MAP_VIRT_FROM_PHYS(MMU_PAGE_1, MMU_USER_PHYS_START_PAGE)
        ; ============================================================================== ;
        ; KERNEL STACK CANNOT BE ACCESSED ANYMORE FROM NOW ON, JUST JUMP TO THE USER CODE!
        ; ============================================================================== ;
        MMU_MAP_VIRT_FROM_PHYS(MMU_PAGE_3, MMU_USER_PHYS_START_PAGE + 2)
        jp MMU_PAGE1_VIRT_ADDR
_zos_load_one_call:
        ; Map two RAM pages to page1 and page2
        MMU_MAP_VIRT_FROM_PHYS(MMU_PAGE_1, MMU_USER_PHYS_START_PAGE)
        MMU_MAP_VIRT_FROM_PHYS(MMU_PAGE_2, MMU_USER_PHYS_START_PAGE + 1)
        ; Put the dev in H
        ld h, d
        ; Destination buffer is first page, in DE
        ld de, MMU_PAGE1_VIRT_ADDR
        ; Push HL as required by VFS routines
        push hl
        call zos_vfs_read
        or a
        jp nz, _zos_load_failed
        ; TODO: loop until BC is 0
        or b
        or c
        jp nz, _zos_load_failed
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

_load_error_1: DEFM "Could not load ", 0
_load_error_2: DEFM " initialization file\n", 0

        SECTION KERNEL_BSS
_file_stats: DEFS STAT_STRUCT_SIZE
_cur_file_name: DEFS 2