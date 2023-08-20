; SPDX-FileCopyrightText: 2023 Shawn Sijnstra <shawn@sijnstra.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "errors_h.asm"
        INCLUDE "osconfig.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "disks_h.asm"
        INCLUDE "interrupt_h.asm"
        INCLUDE "log_h.asm"

    DEFC RAMDISK_LETTER = 'B'

; Allowing space for 64k ZealOS + 256k (max) ROMDISK
    DEFL ramdisk_base = 0x090000

    SECTION KERNEL_DRV_TEXT
ramdisk_init:
    ; Before mounting the disk, make sure it is formatted. To do so, read the first two bytes.
    ; No buffer - use direct ADL mode access
    ld.lil  de,ramdisk_base
    ; Check the data read from the disk. The first byte should be 'Z', the second (version) should be 1
    ; FIXME: this check should be done by the file system?
    ld.l a, (de)
    cp 'Z'
    jr nz, _ramdisk_init_error
    inc.l de
    ld.l a, (de)
    dec a
    jr nz, _ramdisk_init_error
    ; The RAMdisk is properly formatted, mount it as a disk
    ld a, RAMDISK_LETTER
    ; Put the file system in E (rawtable)
    ld e, FS_ZEALFS
    ; Driver structure in HL
    ld hl, _ramdisk_driver
    jp zos_disks_mount
_ramdisk_init_error:
    ld hl, _error_message
    call zos_log_error
    ld a, ERR_FAILURE
    ret
_error_message: DEFM "ZealFS RAMdisk not loaded or correctly formatted\n", 0

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
ramdisk_open:
ramdisk_close:
ramdisk_deinit:
    ; Nothing special to do in this case, return success
    ld a, ERR_SUCCESS
    ret

    ; Read function, called every time the filesystem needs data from the rom disk.
    ; Parameters:
    ;       A  - DRIVER_OP_HAS_OFFSET (0) if the stack has a 32-bit offset to pop
    ;            DRIVER_OP_NO_OFFSET  (1) if the stack is clean, nothing to pop.
    ;       DE - Destination buffer.
    ;       BC - Size to read in bytes. Guaranteed to be equal to or smaller than 16KB.
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
    ; NOTE: DE ISN"T CHECKED YET!
ramdisk_read:
    ; Check if the ramdisk is accessed as a disk or a block
    or a
;    jp nz, _ramdisk_read_as_block  ;Future expansion
    ret nz
    ; The offset must be 16-bit according to the filesystem, so the top of the stack must have
    ; 0x000
    pop hl
    ld a, h
    or l
    pop hl
    jr nz, ramdisk_read_invalid_offset
    ; In practice, BC will also be smaller than 256 when called from the FS, so don't accept
    ; bigger size for now.
    or b
    jr nz, ramdisk_read_invalid_size
        ; Convert addresses to eZ80 address space on Agon
        ld      (source_ez80+2),hl
        ld      (dest_ez80+2),de
        ld      (length_ez80+2),bc

;currently compiled on an absolute base address of 0x040000h in Agon Light
source_ez80:
       ld.lil      hl,ramdisk_base
dest_ez80:
       ld.lil      de,40000h
length_ez80:
       ld.lil      bc,00000h

       push bc
        ENTER_CRITICAL()
        ldir.l
        EXIT_CRITICAL()
        pop     bc      ;number of bytes read
        xor a
        ret

ramdisk_read_invalid_size:
    ld a, ERR_INVALID_PARAMETER
    ret
ramdisk_read_invalid_offset:
    ld a, ERR_INVALID_OFFSET
    ret
    ; Jump to here if the ramdisk is accessed as a block, which means
    ; we have to determine the offset from our static context.
_ramdisk_read_as_block:
;   ld hl, _ramdisk_read_from
;    jp _ramdisk_operation_offset
_ramdisk_write_as_block:
;    ld hl, _ramdisk_write_to
    ; Fall-through

    ; Perform a read or a write according to the offset stored statically
    ; Parameters:
    ;   HL - Routine to call with the offset
    ;   BC - Size to read/wrote
    ;   DE - Destination buffer
_ramdisk_operation_offset:
    ; If BC is bigger or equal to 256, adjust it to 0xFF
    ld a, b
    or a
    jr z, _ramdisk_op_block_no_adjust
    ld bc, 0xff
_ramdisk_op_block_no_adjust:
    ; Make sure C is not zero either
    or c
    ret z
    ; C is not zero, we can continue safely
    push hl
    ld hl, (_ramdisk_offset)
    ; If the offset is 0xFFFF, we reached the end of the ramdisk, exit
    inc hl
    ld a, h
    or l
    jr z, _ramdisk_op_block_end_of_ramdisk
    dec hl
    ; For the moment, make the assumption that the ramdisk is 64KB.
    ; Check if HL += C triggers an overflow. Use C - 1 instead to avoid testing
    ; both nc and z flags after the adc
    ld a, c
    dec a
    add l
    ; If a carry occurred, check if H overflows
    ld a, 0
    adc h
    jr nc, _ramdisk_op_block_no_carry
    ; We reached the end of the ramdisk, set C = -L
    ld a, l
    neg
    ld c, a
_ramdisk_op_block_no_carry:
    ; Save the offset in order to update it later and get the routine to call
    ex (sp), hl
    call _ramdisk_op_call_hl
    pop hl
    or a
    ret nz
    ; No error, we can calculate the new offset from BC
    add hl, bc
    ld (_ramdisk_offset), hl
    ret
    ; Load the offset from the static variable in HL before calling the routine that
    ; was pointed by HL at first
_ramdisk_op_call_hl:
    push hl
    ld hl, (_ramdisk_offset)
    ret ; This will call the original address that was in HL
_ramdisk_op_block_end_of_ramdisk:
    pop hl      ; Clean the stack
    ld bc, 0    ; Read/write 0 bytes
    xor a       ; Success
    ret

    ; Write function, called every time the filesystem needs to save data.
    ; Parameters:
    ;       A  - DRIVER_OP_HAS_OFFSET (0) if the stack has a 32-bit offset to pop
    ;            DRIVER_OP_NO_OFFSET  (1) if the stack is clean, nothing to pop.
    ;       DE - Source buffer.
    ;       BC - Size to read in bytes. Guaranteed to be equal to or smaller than 16KB.
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
    ; NOTE: DE ISN"T CHECKED YET!
ramdisk_write:
    ; Check if the ramdisk is accessed as a disk or a block
    or a
;    jp nz, _ramdisk_write_as_block ;future expansion
    ret nz
    ; The offset must be 16-bit according to the filesystem, so the top of the stack must have
    ; 0x000
    pop hl
    ld a, h
    or l
    pop hl
    jr nz, ramdisk_read_invalid_offset
    or b
    jr nz, ramdisk_read_invalid_size
; Convert addresses to eZ80 address space on Agon
        ld      (destw_ez80+2),hl
        ld      (sourcew_ez80+2),de
        ld      (lengthw_ez80+2),bc

;currently compiled on an absolute base address of 0x040000h in Agon Light
sourcew_ez80:
       ld.lil      hl,40000h
destw_ez80:
       ld.lil      de,ramdisk_base
lengthw_ez80:
       ld.lil      bc,00000h

       push bc
        ENTER_CRITICAL()
        ldir.l
        EXIT_CRITICAL()
        pop     bc      ;number of bytes read
        xor a
        ret


ramdisk_seek:
ramdisk_ioctl:
    ld a, ERR_NOT_IMPLEMENTED
    ret

    SECTION KERNEL_BSS
_ramdisk_buffer: DEFS 2
_ramdisk_offset: DEFS 2

    SECTION KERNEL_DRV_VECTORS
_ramdisk_driver:
NEW_DRIVER_STRUCT("DSK1", \
                  ramdisk_init, \
                  ramdisk_read, ramdisk_write, \
                  ramdisk_open, ramdisk_close, \
                  ramdisk_seek, ramdisk_ioctl, \
                  ramdisk_deinit)