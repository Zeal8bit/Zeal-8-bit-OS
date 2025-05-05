; SPDX-FileCopyrightText: 2023-2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "errors_h.asm"
    INCLUDE "osconfig.asm"
    INCLUDE "mmu_h.asm"
    INCLUDE "drivers_h.asm"
    INCLUDE "vfs_h.asm"
    INCLUDE "disks_h.asm"
    INCLUDE "interrupt_h.asm"
    INCLUDE "i2c_h.asm"
    INCLUDE "log_h.asm"
    INCLUDE "fs/zealfs_h.asm"

    DEFC I2C_EEPROM_DISK_LETTER = 'B'
    DEFC I2C_EEPROM_ADDRESS = 0x50
    DEFC I2C_MAX_WRITE_SIZE = 64
    DEFC I2C_PAGE_BOUND_MASK = I2C_MAX_WRITE_SIZE - 1

    SECTION KERNEL_DRV_TEXT
eeprom_init:
    ; Before mounting the disk, make sure it is formatted. To do so, read the first two bytes.
    ; Re-use the same buffer for write and reads.
    ld hl, 0
    ld (_eeprom_buffer), hl
    ld (_eeprom_offset), hl
    ld hl, _eeprom_buffer
    ld d, h
    ld e, l
    ld bc, 0x0202 ; B and C set to 2
    ld a, I2C_EEPROM_ADDRESS
    call i2c_write_read_device
    or a
    ; If the device didn't reply, do not mount it (of course)
    jr nz, _eeprom_init_error
    ; Check the data read from the disk. The first byte should be 'Z', the second (version) should be 1
    ; FIXME: this check should be done by the file system?
    ld a, (de)
    cp 'Z'
    jr nz, _eeprom_format_error
    inc de
    ld a, (de)
    cp ZEALFS_VERSION
    jr nz, _eeprom_format_error
    ; The EEPROM is properly formatted, mount it as a disk
    ld a, I2C_EEPROM_DISK_LETTER
    ; Put the file system in E (rawtable)
    ld e, FS_ZEALFS
    ; Driver structure in HL
    ld hl, _eeprom_driver
    jp zos_disks_mount
_eeprom_init_error:
    ld hl, _error_message
    call zos_log_error
    ld a, ERR_FAILURE
    ret
_error_message: DEFM "EEPROM not connected\n", 0
_eeprom_format_error:
    ld hl, _format_message
    call zos_log_warning
    ; Return success to allow programs to open it as a block device
    xor a
    ret
_format_message: DEFM "EEPROM not formatted\n", 0

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
eeprom_open:
    xor a
    ld (_eeprom_end), a
    ld h, a
    ld l, a
    ld (_eeprom_offset), hl
    ret
eeprom_close:
eeprom_deinit:
    ; Nothing special to do in this case, return success
    ld a, ERR_SUCCESS
    ret


    ; Routine that returns the current offset of the EEPROM in HL and checks how many
    ; bytes we can operate at most.
    ; Parameters:
    ;   BC - Size to read or write (requested by the user)
    ; Returns:
    ;   HL - Offset on the EEPROM
    ;   BC - New size to read or write
    ; Alters:
    ;   A, BC, HL
_eeprom_static_offset_and_size:
    ; Check if we reached the end of the EEPROM already
    ld a, (_eeprom_end)
    or a
    jr nz, _eeprom_static_return_0
    ld hl, (_eeprom_offset)
    ; Special case if HL is 0, we can return directly
    ld a, h
    or l
    ret z
    push hl
    ; Returns the minimum between BC and (0x10000 - HL) <=> -HL
    ld a, h
    cpl
    ld h, a
    ld a, l
    cpl
    ld l, a
    inc hl
    ; Compare HL and BC, keep the minimum
    ; carry is reset because of OR instruction above
    sbc hl, bc
    jr nc, _eeprom_static_bc_min
    ; HL was the minimum, reset it and store it in BC
    add hl, bc
    ld b, h
    ld c, l
_eeprom_static_bc_min:
    ; BC is the minimum, return it
    pop hl
    ret
_eeprom_static_return_0:
    ; No need to set the offset
    xor a
    ld b, a
    ld c, a
    ret


    ; Update the static offset according to the given BC (bytes read/written)
    ; Parameters:
    ;   A - Error of the previous call
    ;   BC - Bytes read or written
    ; Returns:
    ;   Same as read/write functions
    ; Alters:
    ;   A, HL, DE
_eeprom_update_offset:
    or a
    ret nz
    ld hl, (_eeprom_offset)
    add hl, bc
    ld (_eeprom_offset), hl
    ret nc
    ; Carry, we reached the end of the EEPROM
    inc a   ; A = 1
    ld (_eeprom_end), a
    dec a
    ret


    ; Set the 'current address' of the EEPROM in the hardware
    ; Parameters:
    ;   HL - New 'current address'
    ; Returns:
    ;   A - Error code
    ; Alters:
    ;   A, HL
eeprom_set_current_address:
    push bc
    ; Set the 'current address' in the I2C chip
    ; We must store the offset (HL) in big-endian in a buffer
    ld a, h
    ld h, l
    ld l, a
    ld (_eeprom_buffer), hl
    ld hl, _eeprom_buffer
    ld a, I2C_EEPROM_ADDRESS
    ld b, 2 ; 16-bit offset
    call i2c_write_device
    pop bc
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
eeprom_read:
    ; Check if the EEPROM is accessed as a disk or a block
    or a
    jp z, _eeprom_read_as_fs
    ; Get the offset from the static variable
    call _eeprom_static_offset_and_size
    call _eeprom_read_from
    jp   _eeprom_update_offset
_eeprom_read_as_fs:
    ; The offset must be 16-bit according to the filesystem, so the top of the stack must have
    ; 0x0000
    pop hl
    ld a, h
    or l
    pop hl
    jr nz, eeprom_read_invalid_offset
_eeprom_read_from:
    ; Make sure BC is not 0
    ld a, b
    or c
    ret z
    call eeprom_set_current_address
    or a
    ret nz
    ; Start reading all the bytes from the I2C EEPROM, the I2C driver now supports
    ; 16-bit buffer sizes (BC) for reads.
    ; DE contains the user buffer to fill
    ; BC contains the number of bytes to read
    ; HL can be re-used
    ld a, I2C_EEPROM_ADDRESS
    ex de, hl
    ; Doesn't alter the number of bytes to read
    jp i2c_read_device
eeprom_read_invalid_offset:
    ld a, ERR_INVALID_OFFSET
    ret


    ; Write function, called everytime the file system needs to write to the disk.
    ; Parameters:
    ;       A  - DRIVER_OP_HAS_OFFSET (0) if the stack has a 32-bit offset to pop
    ;            DRIVER_OP_NO_OFFSET  (1) if the stack is clean, nothing to pop.
    ;       DE - Destination buffer.
    ;       BC - Size to write in bytes. Guaranteed to be equal to or smaller than 16KB.
    ;
    ;       ! IF AND ONLY IF A IS 0: !
    ;       Top of stack: 32-bit offset. MUST BE POPPED IN THIS FUNCTION.
    ;              [SP]   - Upper 16-bit of offset
    ;              [SP+2] - Lower 16-bit of offset
    ; Returns:
    ;       A  - ERR_SUCCESS if success, error code else
    ;       BC - Number of bytes written.
    ; Alters:
    ;       This function can alter any register.
eeprom_write:
    ; Check if the EEPROM is accessed as a disk or a block
    or a
    jp z, _eeprom_write_as_fs
    ; Get the offset from the static variable
    call _eeprom_static_offset_and_size
    call _eeprom_write_to
    jp   _eeprom_update_offset
_eeprom_write_as_fs:
    ; The offset must be 16-bit according to the filesystem, so the top of the stack must have
    ; 0x0000
    pop hl
    ld a, h
    or l
    pop hl
    jr nz, eeprom_read_invalid_offset
_eeprom_write_to:
    push bc
    ; We can only write I2C_MAX_WRITE_SIZE at once on I2C EEPROMs. Thus,
    ; we have to iterate until BC is 0. Moreover, we cannot cross page boundary.
    ; L contains the offset in the current I2C page, calculate the minimum between
    ; I2C_MAX_WRITE_SIZE - (L & (I2C_MAX_WRITE_SIZE - 1)) and C
    ld a, I2C_PAGE_BOUND_MASK
    ; A = Offset of HL in the current page (HL % I2C_MAX_WRITE_SIZE)
    and l
    ; If the result is 0, the offset is already a multiple of 64, optimize and jump directly
    ; to the write-page loop
    jr z, _eeprom_write_page_loop
    ; A = PAGE_SIZE - Offset
    neg
    add I2C_MAX_WRITE_SIZE
    ; A contains the maximum amount of bytes we can write in the current I2C page
    ; Compare it to C
    cp c
    jr c, _eeprom_write_a_bytes
    ; C is smaller or equal to A, so write C bytes
    ld a, c
_eeprom_write_a_bytes:
    ; Now, let's write A bytes from DE to offset HL
    ld b, a     ; save the bytes we are going to write in A
    ; We can freely re-use HL now since the hardware contains the offset to start writing from
    push bc     ; preserve the remaining size
    call _eeprom_write_page
    pop bc
    or a
    jr nz, _eeprom_failure
    ; Calculate the remaining size, in other words, C = C - B
    ld a, c
    sub b
    ; A contains the lower byte of the remaining size to write
    pop bc
    push bc ; Keep BC on the stack to return the number of bytes written
    ld c, a
_eeprom_write_page_loop:
    ; BC contains the remaining bytes to write, the address/offset is aligned on I2C_MAX_WRITE_SIZE for sure,
    ; so calculate the number of pages to write: (BC / I2C_MAX_WRITE_SIZE) <=> BC >> 6
    ; We need to store the number of pages
    ASSERT(I2C_MAX_WRITE_SIZE == 64)
    ld a, c
    push af ; Used to calculate the number of bytes remaining after the page loop
    rlca
    rlca
    and 3
    ld c, a
    ld a, b
    rlca
    rlca
    ld b, a
    and 0xfe
    or c
    ld c, a
    ld a, b
    and 3
    ld b, a
_eeprom_write_bc_pages:
    ; Check if BC is 0
    ld a, b
    or c
    jr z, _eeprom_write_loop_end
    ; Write a whole page
    push bc
    ld b, I2C_MAX_WRITE_SIZE
    call _eeprom_write_page
    or a
    jr nz, _eeprom_i2c_failure
    pop bc
    dec bc
    jp _eeprom_write_bc_pages
_eeprom_write_loop_end:
    ; Check if we have any remaining bytes to write (< I2C_MAX_WRITE_SIZE)
    pop af
    and I2C_PAGE_BOUND_MASK
    jr z, _eeprom_write_success
    ld b, a
    call _eeprom_write_page
    or a
    jr nz, _eeprom_i2c_failure
_eeprom_write_success:
    ; Success, we can return BC
    pop bc
    xor a
    ret
_eeprom_i2c_failure:
    pop bc
    pop bc
    ret
_eeprom_failure:
    pop bc
    ld a, ERR_FAILURE
    ret


    ; Parameters:
    ;   B - Number of bytes to write (at most 64, to support both 24C256 and 24C512)
    ;   HL - Address to write to
    ;   DE - Buffer containing the bytes to write
    ; Returns:
    ;   A : success or error code
    ;   HL : HL += B
    ;   DE : DE += B
    ; Alters:
    ;   A, BC
_eeprom_write_page:
    ; We must store the offset in big-endian in a buffer
    push hl
    push de
    push bc
    ld a, l
    ld (_eeprom_buffer + 1), a
    ld a, h
    ld hl, _eeprom_buffer
    ld (hl), a
    ;   A - 7-bit device address
    ;   DE - Register address buffer
    ;   C  - Size of the register address buffer, can be 0, which ignores DE
    ;   HL - Buffer to write on the bus
    ;   B - Size of the buffer, must not be 0
    ld a, I2C_EEPROM_ADDRESS
    ex de, hl
    ld c, 2
    call i2c_write_double_buffer
    or a
    ; If the transfer was a success, we have to wait for the write to finish
    call z, eeprom_write_poll
    pop bc
    pop de
    pop hl
    ; HL += B
    ld c, b
    ld b, 0
    add hl, bc
    ; DE += B
    ex de, hl
    add hl, bc
    ex de, hl
    ret


    ; After a write, the EEPROM will stop responding until the write is
    ; done internally. We have to poll the device until is responds again.
    ; Returns:
    ;   A - 0
    ; Alters:
    ;   A, BC, DE, HL
eeprom_write_poll:
    ; Read a dummy byte from the device, only to see if it responds
    ; Parameters:
    ;   A - 7-bit device address
    ;   HL - Buffer to store the bytes read
    ;   BC - Size of the buffer
    ld bc, 1
_eeprom_write_poll_loop:
    ld a, I2C_EEPROM_ADDRESS
    ld hl, _eeprom_buffer
    call i2c_read_device
    or a
    jr nz, _eeprom_write_poll_loop
    ret


    ; Move the offset to a new position.
    ; The new position is a 32-bit value, it can be absolute or relative
    ; (to the current position or the end), depending on the WHENCE parameter.
    ; Parameters:
    ;       H - Opened dev number getting seeked.
    ;       BCDE - 32-bit offset, signed if whence is SEEK_CUR/SEEK_END.
    ;              Unsigned if SEEK_SET.
    ;       A - Whence. Can be SEEK_CUR, SEEK_END, SEEK_SET.
    ; Returns:
    ;       A - ERR_SUCCESS on success, error code else.
    ;       BCDE - Unsigned 32-bit offset. Resulting offset.
    ; Alters:
    ;       A, BC, DE, HL
eeprom_seek:
    ; Ignore the highest word of the offset
    cp SEEK_SET
    jr z, _eeprom_seek_set
    cp SEEK_CUR
    jr z, _eeprom_seek_cur
    cp SEEK_END
    jr z, _eeprom_seek_end
    ld a, ERR_INVALID_PARAMETER
    ret
_eeprom_seek_end:
    ; Equivalent to set -DE
    xor a
    ld h, a
    ld l, a
    sbc hl, de
    ex de, hl
    ; Fall-through
_eeprom_seek_set:
    ld (_eeprom_offset), de
    xor a
    ret
_eeprom_seek_cur:
    ld hl, (_eeprom_offset)
    add hl, de
    ld (_eeprom_offset), hl
    xor a
    ret


eeprom_ioctl:
    ld a, ERR_NOT_IMPLEMENTED
    ret

    SECTION KERNEL_BSS
_eeprom_buffer: DEFS 2
_eeprom_offset: DEFS 2
_eeprom_end: DEFS 1

    SECTION KERNEL_DRV_VECTORS
_eeprom_driver:
NEW_DRIVER_STRUCT("DSK1", \
                  eeprom_init, \
                  eeprom_read, eeprom_write, \
                  eeprom_open, eeprom_close, \
                  eeprom_seek, eeprom_ioctl, \
                  eeprom_deinit)