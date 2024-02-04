; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "errors_h.asm"
        INCLUDE "osconfig.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "disks_h.asm"
        INCLUDE "interrupt_h.asm"


        SECTION KERNEL_DRV_TEXT
romdisk_init:
        ; Mount this romdisk as the default disk
        call zos_disks_get_default
        ; Default disk in A
        ; Put the file system in E (rawtable)
        ld e, FS_RAWTABLE
        ; Driver structure in HL
        ld hl, _romdisk_driver
        call zos_disks_mount
        ; A has the status, return it if error
        or a
        ret nz
        ; Else, return ERR_DRIVER_HIDDEN as we don't want this driver to be
        ; directly used (as a block device) by users.
        ld a, ERR_DRIVER_HIDDEN
        ret

romdisk_deinit:
        ld a, ERR_SUCCESS
        ret

        ; Open function, called every time a file is opened on this driver
        ; Note: This function should not attempt to check whether the file exists or not,
        ;       the filesystem will do it. Instead, it should perform any preparation
        ;       (if needed) as multiple reads will occur.
        ; Parameters:
        ;       BC - Name of the file to open
        ;       A  - Flags
        ; Returns:
        ;       A - ERR_SUCCESS if success, error code else
        ; Alters:
        ;       A, BC, DE, HL (any of them can be altered, caller-saved)
romdisk_open:
romdisk_close:
        ; Nothing special to do in this case, return success
        ld a, ERR_SUCCESS
        ret

        ; Read function, called every time the filesystem needs data from the rom disk.
        ; Parameters:
        ;       A  - DRIVER_OP_HAS_OFFSET (0) if the stack has a 32-bit offset to pop
        ;            DRIVER_OP_NO_OFFSET  (1) if the stack is clean, nothing to pop.
        ;       DE - Destination buffer.
        ;       BC - Size to read in bytes. Guaranteed to be equal to or smaller than 16KB.
        ;            TODO: Not guaranteed in the case of no-MMU configuration anymore...
        ;
        ;       ! IF AND ONLY IF A IS 0: !
        ;       Top of stack: 32-bit offset. MUST BE POPPED IN THIS FUNCTION.
        ;              [SP]   - Upper 16-bit of offset
        ;              [SP+2] - Lower 16-bit of offset
        ; Returns:
        ;       A  - ERR_SUCCESS if success, error code else
        ;       BC - Number of bytes read.
        ; Alters:
        ;       This function can alter any register.
romdisk_read:
        ; The driver being registered as hidden, A should always be 0 here
        or a
        ret nz
        ; Before mapping the ROMDISK to a page, we have to check which page is free
        ; The 1st one is the current code and the 4th one is kernel RAM.
        ; If DE is mapped in the 2nd one, ROMDISK will be mapped in the 3rd.
        ; Else, ROMDISK must be mapped in the 2nd.
        ld a, d
        ; Keep the upper two bits only
        rlca
        rlca
        and 3
        dec a
        jp z, _romdisk_read_to_page1
        dec a
        jp z, _romdisk_read_to_page2
        dec a
        ; In the case where the destination buffer is in the last page,
        ; we assume this call has been performed by the kernel, and so,
        ; the page is valid.
        jp z, _romdisk_read_to_page2
        ; Don't accept page 0 though, as this is the place this code is executed from.
        ; Error, clean the stack!
        pop hl
        pop hl
        ld a, ERR_INVALID_VIRT_PAGE
        ret
_romdisk_read_to_page1:
        ; Destination buffer is in the second page (index 1), use third page
        ; Backup the MMU configuration
        MMU_GET_PAGE_NUMBER(MMU_PAGE_2)
        ld (_romdisk_mmu_conf), a
        ; Make sure the offset is not bigger than 512KB. The flash on zeal 8-bit computer
        ; is either 256KB or 512KB. Thus, the offset must have its upper 32-19 = 13 bits to 0
        pop hl
        ; Check offset
        ld a, h
        or a
        ; H must be 0, L's highest 5 bit must be 0. In other words, L must be 7 or lower.
        jp nz, _romdisk_read_offset_error
        or l
        ; This operation must set a carry, meaning that L is smaller or equal to 7
        cp 8
        jp nc, _romdisk_read_offset_error
        ; The offset is in range. The pages are 16KB big, so divide the offset by 16KB
        ; Divide by 16KB = right shift 14 bits
        ; The page index will be A = bits x,x,x,18,17,16,15,14
        ; A already contains bits 18, 17 and 16.
        ; Get the lowest 16-bit index
        pop hl
        rlc h
        rla
        rlc h
        rla
        ; Now A contains bits 0,0,0,18,17,16,15,14
        ; However, ROMDISK doesn't start at page 0 of flash,
        ; thus, we have to add to A the start page index
        add CONFIG_ROMDISK_ADDRESS / KERN_MMU_VIRT_PAGES_SIZE
        MMU_SET_PAGE_NUMBER(MMU_PAGE_2)
        ; Page is mapped! Restore HL to an actual address between 0 and 16KB
        ld a, h
        rrca
        rrca
        and 0x3f ; Keep 6 bits only
        ; AL now defines a 8+6 = 14-bit address
        ; Add to A the index of the third page
        or KERN_MMU_PAGE2_VIRT_ADDR >> 8
        ld h, a
        ; HL is now our source buffer!
        push bc
        ; Before starting the copy, we must make sure that the source buffer+size is NOT crossing 16KB
        ; boundary!
        ; In other words, (HL + BC) must still point to the same page, else we would need 2 ldir
        call _romdisk_copy_if_cross_boundary
        jr z, _romdisk_copy_no_remap
        ; A cross-boundary copy is occurring, we have to remap the flash/rom to the next page
        MMU_GET_PAGE_NUMBER(MMU_PAGE_2)
        inc a
        MMU_SET_PAGE_NUMBER(MMU_PAGE_2)
_romdisk_copy_no_remap:
        ldir
        pop bc
        ; Map back the MMU config
        ld a, (_romdisk_mmu_conf)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_2)
        ; Success
        xor a
        ret
_romdisk_read_to_page2:
        ; Destination buffer is in the third page (index 2)
        ; Same as above.
        ; TODO: optimize in space.
        MMU_GET_PAGE_NUMBER(MMU_PAGE_1)
        ld (_romdisk_mmu_conf), a
        pop hl
        ld a, h
        jp nz, _romdisk_read_offset_error
        or l
        cp 8
        jp nc, _romdisk_read_offset_error
        pop hl
        rlc h
        rla
        rlc h
        rla
        add CONFIG_ROMDISK_ADDRESS / KERN_MMU_VIRT_PAGES_SIZE
        MMU_SET_PAGE_NUMBER(MMU_PAGE_1)
        ld a, h
        rrca
        rrca
        and 0x3f ; Keep 6 bits only
        or KERN_MMU_PAGE1_VIRT_ADDR >> 8
        ld h, a
        push bc
        ; Same as above, check the comment.
        call _romdisk_copy_if_cross_boundary
        jr z, _romdisk_copy_no_remap_1
        ; A cross-boundary copy is occurring, we have to remap the flash/rom to the next page
        MMU_GET_PAGE_NUMBER(MMU_PAGE_1)
        inc a
        MMU_SET_PAGE_NUMBER(MMU_PAGE_1)
_romdisk_copy_no_remap_1:
        ldir
        pop bc
        ld a, (_romdisk_mmu_conf)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_1)
        xor a
        ret
_romdisk_read_offset_error:
        ; Clean stack
        pop hl
        ld a, ERR_INVALID_OFFSET
        ret

        ; Function performing a first copy of HL into DE if HL + BC is crossing the 16KB boundary
        ; (if a single copy would cross the current page)
        ; Parameters:
        ;       HL - Source pointer
        ;       BC - Bytes count
        ;       DE - Destination pointer
        ; Returns:
        ;       HL - New source
        ;       BC - New size
        ;       DE - New destination pointer
        ;       Z  - No cross-boundary occurs
        ;       NZ  - Cross-boundary occurs
        ; Alters:
        ;       A
_romdisk_copy_if_cross_boundary:
        ; Check if HL+BC crosses pages
        ld a, h
        push hl
        add hl, bc
        xor h
        and 0xc0        ; Keep the highest 2-bits
        jr z, _romdisk_copy_if_cross_boundary_no
        ; HL+BC crosses pages, check how many bytes it is crossing
        ; Remove the upper 2 bits.
        ld a, h
        and 0x3f
        ld h, a
        ; Calculate the current size to copy: BC - HL.
        ; We are sure that BC is greater than HL.
        ld a, c
        sub l
        ld c, a
        ld a, b
        sbc h
        ld b, a
        ; BC has now the first size to copy, HL has the "new size" to return.
        ; Store the new size on the stack and get the original address
        ex (sp), hl
        ldir
        ; Perform the copy, BC is 0 now, give to it the size to return
        pop bc
        ; HL is now pointing to the next MMU page, so it's either 0x8000 or 0xC000,
        ; Set to the "previous" page, first byte. Subtract 0x40 to H.
        ld a, h
        sub 0x40        ; This will reset z flag because H will not be 0.
        ld h, a
        ; DE is correct, don't change it. Stack is clean.
        ret
_romdisk_copy_if_cross_boundary_no:
        pop hl
        ret   ; No cross-boundary before copying


        ; API: Same as the routine above but for writing.
        ; No supported for romdisk.
romdisk_write:
        or a
        ld a, ERR_READ_ONLY
        ; Directly return if the stack is cleaned
        ret nz
        ; Clean the stack
        pop hl
        pop hl
        ret

romdisk_seek:
        ; Seek shouldn't be called as it should be implemented by the filesystem.
romdisk_ioctl:
        ld a, ERR_NOT_IMPLEMENTED
        ret

        SECTION KERNEL_BSS
_romdisk_mmu_conf: DEFS 1

        SECTION KERNEL_DRV_VECTORS
_romdisk_driver:
NEW_DRIVER_STRUCT("RDSK", \
                  romdisk_init, \
                  romdisk_read, romdisk_write, \
                  romdisk_open, romdisk_close, \
                  romdisk_seek, romdisk_ioctl, \
                  romdisk_deinit)