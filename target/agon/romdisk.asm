; SPDX-FileCopyrightText: 2023 Shawn Sijnstra <shawn@sijnstra.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "errors_h.asm"
        INCLUDE "osconfig.asm"
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
        ; This is the last driver, enable interrupts here
        INTERRUPTS_ENABLE()
        ; Else, return ERR_DRIVER_HIDDEN as we don't want this driver to be
        ; directly used by users.
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
_romdisk_read_to_page2:
        ; Destination buffer is in the second page (index 1), use third page
        ; Make sure the offset is not bigger than 512KB. The flash on zeal 8-bit computer
        ; is either 256KB or 512KB. Thus, the offset must have its upper 32-19 = 13 bits to 0
        ; For Agon version, let's limit the RAWTABLE built-in filesystem to 256k for now.
        pop hl
        ; Check offset
        ld a, h
        or a
        ; H must be 0, L's highest 5 bit must be 0. In other words, L must be 7 or lower.
        jp nz, _romdisk_read_offset_error
        or l
        ; This operation must set a carry, meaning that L is smaller or equal to 7
;        cp 8
        cp 4    ;256k limit
        jp nc, _romdisk_read_offset_error
        ; Add offset to source location and push to the ez80 load location
        add     5
        ld      (source_ez80+4),a
        ; Get the lowest 16-bit index
        pop     hl
        ; Convert addresses to eZ80 address space on Agon
        ld      (source_ez80+2),hl
        ld      (dest_ez80+2),de
        ld      (length_ez80+2),bc

;currently compiled on an absolute base address of 0x040000h in Agon Light
source_ez80:
       ld.lil      hl,50000h
dest_ez80:
       ld.lil      de,40000h
length_ez80:
       ld.lil      bc,00000h

        ENTER_CRITICAL()
        push    bc
        ldir.l
        pop     bc      ;number of bytes read
        EXIT_CRITICAL()
        xor a
        ret

_romdisk_read_offset_error:
        ; Clean stack
        pop hl
        ld a, ERR_INVALID_OFFSET
        ret

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