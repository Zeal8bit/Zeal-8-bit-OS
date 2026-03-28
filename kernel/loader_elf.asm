; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "errors_h.asm"
        INCLUDE "osconfig.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "strutils_h.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "loader_h.asm"

        DEFC ELF_ET_EXEC     = 2
        DEFC ELF_EM_Z80      = 220
        DEFC ELF_TYPE_OFST   = 16
        DEFC ELF_MACH_OFST   = 18
        DEFC ELF_ENTRY_OFST  = 24
        DEFC ELF_PHOFF_OFST  = 28
        DEFC ELF_PHENT_OFST  = 42
        DEFC ELF_PHNUM_OFST  = 44

        DEFC ELF_PHDR_SIZE     = 32
        DEFC ELF_PT_LOAD       = 1
        DEFC ELF_P_TYPE_OFST   = 0
        DEFC ELF_P_OFFSET_OFST = 4
        DEFC ELF_P_VADDR_OFST  = 8
        DEFC ELF_P_FILESZ_OFST = 16
        DEFC ELF_P_MEMSZ_OFST  = 20

        EXTERN zos_vfs_open_internal
        EXTERN zos_vfs_read_internal

        EXTERN _load_buffer_header
        EXTERN zos_loader_map_jump_entry

        SECTION KERNEL_TEXT

        ; Read the header from the opened dev file to load
        ; Parameters:
        ;       D - Opened dev
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ;         (Z flag is set accordingly)
        ;       H - Binary format type
        PUBLIC zos_elf_read_header
zos_elf_read_header:
        ld h, d
        ld bc, ELF_HEADER_SIZE
        ld de, _load_buffer_header
        call zos_vfs_read_internal
        ld d, h
        or a
        ret nz
        ld a, ELF_HEADER_SIZE
        cp c
        jr nz, _not_elf
        ; Check all the standard header values
        ld hl, (_load_buffer_header)
        ld bc, 0x457f
        sbc hl, bc
        jr nz, _not_elf
        ld hl, (_load_buffer_header + 2)
        ld bc, 0x464c
        sbc hl, bc
        jr nz, _not_elf
        ld hl, (_load_buffer_header + ELF_MACH_OFST)
        ld bc, ELF_EM_Z80
        sbc hl, bc
        jr nz, _invalid_exec
        ld hl, (_load_buffer_header + ELF_TYPE_OFST)
        ld bc, ELF_ET_EXEC
        sbc hl, bc
        jr nz, _invalid_exec
        ld hl, (_load_buffer_header + ELF_ENTRY_OFST)
        ; Allow any virtal address as long as it's not in the first page (0x0000 - 0x3FFF)
        ld a, h
        and 0xc0
        jr z, _invalid_exec
        ; Keep entry point in case it is valid
        ld (s_elf_entry), hl
        ld hl, (_load_buffer_header + ELF_ENTRY_OFST + 2)
        ld a, h
        or l
        jr nz, _invalid_exec
        ; Make sure the the number of program headers is > 0 && < 256
        ld hl, (_load_buffer_header + ELF_PHNUM_OFST)
        ; Make sure it's < 256
        ld a, h
        or a
        jr nz, _invalid_exec
        ; Make sure it's > 0
        or l
        jr z, _invalid_exec
        ; Make sure the entry size is the standard one
        ld hl, (_load_buffer_header + ELF_PHENT_OFST)
        ld bc, ELF_PHDR_SIZE
        sbc hl, bc
        jr nz, _invalid_exec
        ; Return success!
        ld h, BIN_ELF
        xor a
        ret
_invalid_exec:
        ld a, ERR_EXEC_INVALID_FORMAT
        or a
        ret
_not_elf:
        ld h, BIN_RAW
        xor a
        ret


        ; Alters:
        ;       A, DE
zos_elf_phdr_seek_to_section:
        push hl
        push bc
        ld a, (s_elf_dev_snd)
        ld h, a
        ld de, (_load_buffer_header + ELF_P_OFFSET_OFST)
        ld bc, (_load_buffer_header + ELF_P_OFFSET_OFST + 2)
        ld a, SEEK_SET
        call zos_vfs_seek
        pop bc
        pop hl
        ret


        ; Parse the program header ENTRY located in `_load_buffer_header` and
        ; load the data it is pointing to.
        ; Parameters:
        ;       [_load_buffer_header] - Program header entry
        ; Returns:
        ;       Z flag - Success
        ;       NZ flag - Error (in A register)
        ; Alters:
        ;       A, BC, DE, HL
zos_load_phdr:
        ; Make sure the header is of type LOAD, let's simplify and only check the LSB
        ld a, (_load_buffer_header + ELF_P_TYPE_OFST)
        cp ELF_PT_LOAD
        ; Skip any non-LOAD type, not an error
        ld a, ERR_SUCCESS       ; Do not alter flags
        ret nz
        ; PT_LOAD program header, make sure virtual address is in range (0x0000 - 0xffff)
        ld hl, (_load_buffer_header + ELF_P_VADDR_OFST + 2)
        or h
        or l
        ; Make sure the header size is 16-bit
        ld hl, (_load_buffer_header + ELF_P_FILESZ_OFST + 2)
        or h
        or l
        ; Similarly, for the size in memory
        ld hl, (_load_buffer_header + ELF_P_MEMSZ_OFST + 2)
        or h
        or l
        jr nz, _zos_load_phdr_oob
        ; Try to seek to the header content inside the file
        ld a, (s_elf_dev_snd)
        ; Offset in BCDE
        ld de, (_load_buffer_header + ELF_P_OFFSET_OFST)
        ld bc, (_load_buffer_header + ELF_P_OFFSET_OFST + 2)
        ld a, (s_elf_dev_snd)
        ld h, a
        ld a, SEEK_SET
        call zos_vfs_seek
        or a
        ret nz
        ; Make sure memory size >= file size
        ld hl, (_load_buffer_header + ELF_P_MEMSZ_OFST)
        ld bc, (_load_buffer_header + ELF_P_FILESZ_OFST)
        or a
        sbc hl, bc
        jr c, _zos_load_phdr_invalid_exec
        ; Restore HL (size in memory)
        add hl, bc
        ; Make sure virtual address + memory size does not overflow (i.e. is still 16-bit)
        ; Organize as:
        ;       BC - Size in file
        ;       HL - Size in memory
        ;       DE - Virtual address
        ld de, (_load_buffer_header + ELF_P_VADDR_OFST)
        push hl
        add hl, de
        jr c, _zos_load_phdr_oob
        ; We need to pass these parameters
        ; A - Opened dev
        ; DE - Virtual address
        ; BC - Size to load
        ; Out stack has memory size
        ld a, (s_elf_dev_snd)
        ; Keep the size to read from file
        push bc
        call zos_load_file_chunks
        pop bc
        ; Get the size in memory in HL
        pop hl
        ; Return on error
        ret nz
        ; Calculate the bytes to set to 0, and set it BC
        or a
        sbc hl, bc
        ; If 0, return success (A is already 0)
        ret z
        ; We still have to read BC, set the opened dev to 0xFF (to memset to 0)
        ld b, h
        ld c, l
        ; Setting the opened dev to 0xFF will result in a memset(0)
        ld a, 0xff
        jp zos_load_file_chunks
_zos_load_phdr_pop_fail:
        pop bc
        ret
_zos_load_phdr_oob_pop:
        pop hl
_zos_load_phdr_oob:
        ld a, ERR_EXEC_OUT_OF_BOUNDS
        or a
        ret
_zos_load_phdr_invalid_exec:
        ld a, ERR_EXEC_INVALID_FORMAT
        or a
        ret



        PUBLIC zos_elf_load
zos_elf_load:
        ; Seek the ELF file to the program header table 
        ld de, (_load_buffer_header + ELF_PHOFF_OFST)
        ld bc, (_load_buffer_header + ELF_PHOFF_OFST + 2)
        ld a, (g_load_dev)
        ld h, a
        ld a, SEEK_SET
        call zos_vfs_seek
        or a
        jr nz, _zos_close_fail_A
        ; Before actually starting reading the file, open it again, so that we
        ; get a secnd descriptor that will be used to read the secitons content
        ld bc, (g_load_filename)
        ld h, O_RDONLY
        call zos_vfs_open_internal
        or a
        jp m, _zos_elf_open_error
        ld (s_elf_dev_snd), a
        ; File points to the header table!
        ; Keep the entries count in B (guaranteed < 256)
        ld a, (_load_buffer_header + ELF_PHNUM_OFST)
        ld b, a
_zos_elf_load_loop:
        ; Save the counter on the stack
        push bc
        ; Read the header from the file
        ld a, (g_load_dev)
        ld h, a
        ld bc, ELF_PHDR_SIZE
        ld de, _load_buffer_header
        call zos_vfs_read_internal
        jr nz, _zos_elf_load_failed_pop
        ; Make sure we just read the correct amount of bytes        
        ld a, ELF_PHDR_SIZE
        cp c
        jr nz, _zos_elf_load_invalid_exec_pop
        ; Load the header into memory
        call zos_load_phdr
        jr nz, _zos_elf_load_failed_pop
        pop bc
        djnz _zos_elf_load_loop
        ; Success, close the files and execute program
        call _zos_load_close_files
        ; Load the entry point in DE
        ld de, (s_elf_entry)
        jp zos_loader_map_jump_entry

_zos_elf_load_invalid_exec_pop:
        ld a, ERR_EXEC_INVALID_FORMAT
        ; Fall-through
_zos_elf_load_failed_pop:
        pop bc
_zos_load_close_files:
        ; Close both file desciptors (backup the error)
        push af
        ld a, (s_elf_dev_snd)
        ld h, a
        call zos_vfs_close
        ; Close the main one
        jr _zos_close_snd
_zos_elf_open_error:
        ; Error when opening the same file a second time, close the first one
        ; and return an error
        neg
_zos_close_fail_A:
        push af
_zos_close_snd:
        ld a, (g_load_dev)
        ld h, a
        call zos_vfs_close
        pop af
        ret

        SECTION KERNEL_BSS
        ; Secondary opened file descriptor, used to read the sections
s_elf_dev_snd: DEFS 1
s_elf_entry: DEFS 2