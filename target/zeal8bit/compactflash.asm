; SPDX-FileCopyrightText: 2024 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "errors_h.asm"
    INCLUDE "osconfig.asm"
    INCLUDE "mmu_h.asm"
    INCLUDE "drivers_h.asm"
    INCLUDE "vfs_h.asm"
    INCLUDE "disks_h.asm"
    INCLUDE "compactflash_h.asm"
    INCLUDE "fs/rawtable_h.asm"
    INCLUDE "log_h.asm"

    EXTERN byte_to_ascii

    DEFC CF_DISK_LETTER = 'C'

    SECTION KERNEL_DRV_TEXT
cf_init:
  IF CONFIG_TARGET_COMPACTFLASH_TIMEOUT > 0
    ld bc, CONFIG_TARGET_COMPACTFLASH_TIMEOUT
    ld de, 1    ; 1 millisecond
cf_wait:
    in a, (CF_REG_STATUS)
    bit STATUS_BUSY_BIT, a
    jr z, cf_ready
    ; Use kernel's msleep to wait a millisecond
    call zos_time_msleep
    dec bc
    ld a, b
    or c
    jr nz, cf_wait
    ; BC is 0, the timeout is reached...
    jr _cf_init_not_found
cf_ready:
  ELSE ; // CONFIG_TARGET_COMPACTFLASH_TIMEOUT == 0
    ; Timeout is set to 0, in other words, do not wait and check directly the status
    in a, (CF_REG_STATUS)
    bit STATUS_BUSY_BIT, a
    jr nz, _cf_init_not_found
  ENDIF ; // CONFIG_TARGET_COMPACTFLASH_TIMEOUT > 0
    ; Check that the compact flash is connected (RDY bit set)
    bit STATUS_RDY_BIT, a
    jr z, _cf_init_not_found
    ; The CF was found! Enable the 8-bit mode
    ld a, FEATURE_ENABLE_8_BIT
    out (CF_REG_FEATURE), a
    ld a, COMMAND_SET_FEATURES
    out (CF_REG_COMMAND), a
    ; Wait for the CF to be ready again
    ld b, 7
    call wait_for_ready
    ; If A is not zero, 8-bit mode is not supported
    jr nz, _cf_init_not_compatible
    ; Put disk letter in A, file system in E (rawtable) and driver structure in HL
    ld a, CF_DISK_LETTER
    ld e, FS_RAWTABLE
    ld hl, _cf_driver
    call zos_disks_mount
    ; A has the status, return it if error
    or a
    ret nz
    ; Return ERR_DRIVER_HIDDEN as we don't want this driver to be
    ; directly used by users as a block device (yet?).
    ld a, ERR_DRIVER_HIDDEN
    ret
_cf_init_not_compatible:
    ld hl, _not_compatible
    call zos_log_error
    ld a, ERR_FAILURE
    ret
_cf_init_not_found:
    ld hl, _not_found_str
    call zos_log_warning
    xor a
    ret
_not_compatible: DEFM "CompactFlash: 8-bit mode unsupported\n", 0
_not_found_str:  DEFM "No CompactFlash found\n", 0


    ; Routine that waits for the CompactFlash to be ready and not busy.
    ; Parameters:
    ;   B - Timeout in loop count
    ; Returns:
    ;   A - 0 on success, 1 on error, 2 on timeout
wait_for_ready:
    inc b
_cf_is_busy:
    dec b
    jr z, _cf_timeout
    in a, (CF_REG_STATUS)
    bit STATUS_BUSY_BIT, a
    jr nz, _cf_is_busy
    ; Check that RDY bit is set and that BUSY bit is not set
    bit STATUS_RDY_BIT, a
    jr z, _cf_is_busy
    ; Device is ready, return the error bit in A
    and 1 << STATUS_ERR_BIT
    ret
_cf_timeout:
    ld a, 2
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
cf_open:
cf_close:
cf_deinit:
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
_cf_read:
cf_read:
    ; Check if the CF is accessed as a disk or a block (not implemented)
    or a
    jp nz, cf_not_implemented
    pop hl
    ld (_cf_upper_addr), hl
    pop hl  ; Lower 16-bit offset
    ; Check the total amount of sectors to process.
    call cf_process_sec_cnt
    ; ld (_cf_sec_cnt), a
    ; Write to the Compact Flash the LBA address and the sector count
    call cf_prepare_address_and_count
    ; Wait for the CF to be ready
    push bc
    ld b, 255
    call wait_for_ready
    ; Launch the read command
    ld a, COMMAND_READ_SECTORS
    out (CF_REG_COMMAND), a
    ld b, 255 ; Give the compact flash some time to perform the read
    call wait_for_ready
    jr nz, _cf_read_error
    ; The first sector has been read, we can ignore the first bytes (if any)
    ld bc, (_cf_ignore_before)
    ; Cannot be bigger than a sector size, for sure. Check if it is 0.
    ld a, b
    or c
    jr z, _cf_read_ignore_end
_cf_read_before_ignore_start:
    ; "Pop" a byte from the CompactFlash
    in a, (CF_REG_DATA)
    dec bc
    ld a, b
    or c
    jp nz, _cf_read_before_ignore_start
_cf_read_ignore_end:
    ; In theory, we have to calculate the number of bytes remaining in the current sector
    ; and then check the BUSY flag. In pratice, this would require to calculate the number
    ; of bytes remaining in the sector, treat them with inir, subtract from BC (size to read)
    ; and continue. Let's make it simple first.
    ; TODO: Optimize this part by not checking BUSY flag.
    pop bc
    push bc ; Keep it on the stack to return it
    ; TODO: Optimize by using B as a counter.
    ; BC contains the number of bytes to read.
_cf_read_data:
    ; Make sure the CF is not busy
    in a, (CF_REG_STATUS)
    ASSERT(STATUS_BUSY_BIT == 7)
    rlca
    jr c, _cf_read_data
    ; Read the data
    in a, (CF_REG_DATA)
    ld (de), a
    inc de
    dec bc
    ld a, b
    or c
    jp nz, _cf_read_data
    ; Ignore the last part
    ld bc, (_cf_ignore_after)
    ld a, b
    or c
    jr z, _cf_read_success
    ; Perform the "ignore" loop, for sure we won't overlap with another sector
_cf_read_ignore_after:
    in a, (CF_REG_DATA)
    dec bc
    ld a, b
    or c
    jp nz, _cf_read_ignore_after
_cf_read_success:
    pop bc
    xor a
    ret
_cf_read_error:
    pop bc
    ld a, ERR_FAILURE
    ret




    ; Number of sectors to process, including the bytes to ignore before the read,
    ; the ones to actually read and the ones to ignore afterwards
    ; Parameters:
    ;   BC - Number of bytes to process
    ;   HL - Lower 16-bit of the offset/address to process
    ; Returns:
    ;   A  - Number of sectors to process
    ;   [_cf_ignore_before] - Number of bytes to ignore before the process
    ;   [_cf_ignore_after]  - Number of bytes to ignore after the process
    ; Alters:
    ;   A
cf_process_sec_cnt:
    push bc
    push hl
    ; Save the (LSB) number of bytes to ignore since we have it
    ld a, l
    ld (_cf_ignore_before), a
    ; We have to calculate the number of bytes to read + bytes to ignore divided by the sector size
    ; but rounded up. Overall: (BC + (HL % 512) + 511) / 512
    ; HL = (HL % 512) + 512
    ld a, h
    and 1
    ; Take advantage of A current value to save the number of bytes to ignore (upper byte)
    ld (_cf_ignore_before + 1), a
    add 2
    ld h, a
    ; HL = HL - 1, so that HL is (HL % 512) + 511
    dec hl
    add hl, bc
    ; Total number of bytes to process in HL, at most 16.5KB.
    ; Number of sectors to process <=> divide HL by 512
    ld a, h
    srl a
    ; Calculate the number of bytes to ignore AFTER the read: (512 - (HL + 1)) % 512
    ; We need to increment HL because 511 was added to it...
    ld b, h
    ld c, l
    ld hl, 512
    scf
    sbc hl, bc
    ; HL % 512
    srl h   ; Save lowest bit
    ld h, 0
    rl h    ; Restore lowest bit
    ld (_cf_ignore_after), hl
    pop hl
    pop bc
    ret


    ; Prepare the LBA address and the sector count by writing them to the CompactFlash registers
    ; Parameters:
    ;   HL - Lower 16-bit of the offset/address
    ;   [_cf_upper_addr] - Higher 16-bit of the offset/address
    ;   A  - Sector count
    ; Returns:
    ;   None
    ; Alters:
    ;   A, HL
cf_prepare_address_and_count:
    push de
    ; Write the sector count
    out (CF_REG_SEC_CNT), a
    ; Calculate the 24-bit LBA address
    ld de, (_cf_upper_addr)
    ex de, hl
    ; 32-bit address in HLDE, we need to divide the whole address by 512 (sector size)
    srl h
    rr l
    rr d
    ; Ignore E <=> / 256
    ld a, d
    out (CF_REG_LBA_0), a
    ld a, l
    out (CF_REG_LBA_8), a
    ld a, h
    out (CF_REG_LBA_16), a
    ; Address is always 0, upper are fixed to 0xE0 (drive = 0, lba = 1)
    ld a, 0xe0
    out (CF_REG_LBA_24), a
    pop de
    ret


cf_seek:
cf_ioctl:
cf_not_implemented:
    ld a, ERR_NOT_IMPLEMENTED
    ret

    ; API: Same as the read routine but for write. Not supported for CF (yet?).
cf_write:
    or a
    ld a, ERR_READ_ONLY
    ; Directly return if the stack is cleaned
    ret nz
    ; Clean the stack
    pop hl
    pop hl
    ret



    SECTION KERNEL_BSS
    ; Number of 512 bytes sectors to read
_cf_sec_cnt: DEFS 1
    ; Number of bytes to ignore during a read
_cf_ignore_before: DEFS 2
    ; Total number of bytes to ignore after the read is performed (at most 511)
_cf_ignore_after: DEFS 2
_cf_upper_addr: DEFS 2

    SECTION KERNEL_DRV_VECTORS
_cf_driver:
NEW_DRIVER_STRUCT("DSK2", \
                  cf_init, \
                  cf_read, cf_write, \
                  cf_open, cf_close, \
                  cf_seek, cf_ioctl, \
                  cf_deinit)