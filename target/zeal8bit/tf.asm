; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "errors_h.asm"
    INCLUDE "osconfig.asm"
    INCLUDE "drivers_h.asm"
    INCLUDE "vfs_h.asm"
    INCLUDE "disks_h.asm"
    INCLUDE "tf_h.asm"
    INCLUDE "log_h.asm"
    INCLUDE "fs/mbr_h.asm"

    INCLUDE "strutils_h.asm"

    EXTERN byte_to_ascii

    DEFC TF_DISK_LETTER = 'T'
    DEFC COMMAND0_RETRY = 32

    MACRO SEND_COMMAND_R1 num, parameter, crc
        ld a, TF_CMD_MASK | num
        ; Argument = 0
        ld de, parameter >> 16
        ld hl, parameter & 0xffff
        ld b, crc
        ; Number of bytes in the reply
        ld c, 1
        call tf_send_command_get_reply
    ENDM


    MACRO SEND_COMMAND_R7 num, parameter, crc
        ld a, TF_CMD_MASK | num
        ; Argument = 0
        ld de, parameter >> 16
        ld hl, parameter & 0xffff
        ld b, crc
        ; Number of bytes in the reply
        ld c, 5
        call tf_send_command_get_reply
    ENDM


    SECTION KERNEL_DRV_TEXT
tf_init:
    ; Map the SPI controller
    ld a, SPI_CONTROLLER_IDX
    out (IO_MAPPER_BANK), a

    ; Reset the SPI controller
    ld a, SPI_REG_CTRL_RESET
    out (SPI_REG_CTRL), a
    call tf_card_init
    cp TFCARD_ERR_TIMEOUT
    jr z, _tf_init_not_found
    cp TFCARD_ERR_NOT_SUPPORTED
    jr nc, _tf_init_not_compatible

    ; Read a block from the TFcard
    ; Set the buffer to store the result in
    ld hl, rd_buf
    ld (rd_block_arg), hl
    ; Address of the block (DEHL)
    ld de, 0
    ld hl, 0
    ; Size of the data to read (the rest will be ignored)
    ld bc, 512
    call tf_card_read_block

    ; Check the MBR for a ZealFS partition
    ld hl, rd_buf
    ld e, 'Z'
    call mbr_search_partition
    cp ERR_NO_SUCH_ENTRY
    jr z, _tf_init_part_not_found
    cp ERR_INVALID_FILESYSTEM
    jr z, _tf_init_no_mbr

    ; Save the starting sector LBA
    ld (_tf_start_lba), hl
    ld (_tf_start_lba + 2), de

    ld a, l
    push af
    ld a, h
    push af
    ld a, e
    push af
    ld a, d
    push af
    ld hl, _addr
    ld de, rd_buf
    call strformat
    ex de, hl
    call zos_log_info

    ; Register the disk as ZealFS v2
    ld a, TF_DISK_LETTER
    ; Put the file system in E (rawtable)
    ld e, FS_ZEALFS
    ld hl, _tf_driver
    call zos_disks_mount

    ; Return ERR_DRIVER_HIDDEN as we don't want this driver to be
    ; directly used by users as a block device (yet?).
    ld a, ERR_DRIVER_HIDDEN
    ret

_addr:
    DEFM "LBA ", FORMAT_U8_HEX, FORMAT_U8_HEX, FORMAT_U8_HEX, FORMAT_U8_HEX, "\n", 0

_tf_init_not_compatible:
    ld hl, _not_compatible
    jr _tf_warn
_tf_init_part_not_found:
    ld hl, _part_not_found_str
    jr _tf_warn
_tf_init_no_mbr:
    ld hl, _no_mbr_found
    jr _tf_warn
_tf_init_not_found:
    ld hl, _not_found_str
_tf_warn:
    ld b, a ; Save the return value
    call zos_log_warning
    ld a, b
    ret
_no_mbr_found: DEFM "TF: no MBR found\n", 0
_not_compatible: DEFM "TF: incompatible version\n", 0
_not_found_str:  DEFM "TF: not found\n", 0
_part_not_found_str:  DEFM "TF: partition not found\n", 0



    ; Initialize the TF card via SPI.
    ; This routine will send CMD0 a given number of times (COMMAND0_RETRY), before returning
    ; a timeout error.
tf_card_init:
    ; On power-up, the reset signal is asserted more than 1ms, so no need to wait again for the TF card
    ; to be ready. BUT, we still need to generate around 80 clock cycles, with CS as high, @ ~100-200KHz
    ld a, 126
    out (SPI_REG_CLK_DIV), a
    ; Fill the buffer with 8 0xFF bytes
    call spi_fill_fifo_dummy
    ; The out FIFO won't be altered after a transfer, it will still contain 8 FFs, same goes for the length,
    ; we can simply restart the transfer as much as we want
    ld b, 0x8
_tf_card_send_loop:
    ; Start the transfer with CS number 0 de-asserted (high)
    ld a, SPI_REG_CTRL_START | SPI_REG_CTRL_CS_END
    out (SPI_REG_CTRL), a
    ; Wait for the SPI controller to finish the transaction
    call spi_wait_idle
    djnz _tf_card_send_loop
    ; Send CMD0 now, retry COMMAND0_RETRY times
    ld b, COMMAND0_RETRY
_tf_card_loop0:
    push bc
    SEND_COMMAND_R1(0, 0, TF_CMD0_CRC)
    pop bc
    ; If we have already received the reply, and it is a success, Z flag is not set
    jr nz, _tf_init_cmd0_success
    djnz _tf_card_loop0
    ; Timeout, command 0 never succeeded
_tf_card_wait_timeout:
    ld a, TFCARD_ERR_TIMEOUT
    ret
_tf_init_cmd0_success:
    ; Send command 8, which is supported by cards following the 2.0 specification
    SEND_COMMAND_R7(8, 0x1aa, 0x87)
    jr z, _tf_card_wait_timeout
    ; A lowest bit must not be 0 !
    bit 0, a
    jr z, _tf_card_failure
    ; If RET is 0x55, we have an old card
    cp TF_ILL_CMD
    jr nz, _tf_card_new_spec
    ld a, 1
    ld (tf_old_spec), a
_tf_card_new_spec:
    ; Send ACMD41 to check if it is an SDHC/SDXC card
    call tf_card_acmd41
    jr z, _tf_card_wait_timeout
    ; If A is 0, it's a success, not an SDHC/SDXC card
    or a
    jr z, _tf_card_acmd41_done
    ; A is not 0, check if it is an illegal command
    cp TF_ILL_CMD
    jr nz, _tf_card_acmd41_valid
    ; ACMD41 is invalid, send CMD1 instead (old cards)
    call tf_card_cmd1
    jr nz, _tf_card_acmd41_done
    ; Timeout error
    jr _tf_card_wait_timeout
_tf_card_acmd41_valid:
    ; Command is valid, but the response was not 0, so the card is bigger than 4GB!
    ; Not supported for now
    ld a, TFCARD_ERR_NOT_SUPPORTED
    ret
_tf_card_acmd41_done:
    ; ACMD41 succeeded, check if we have an SDHC/SDXC or a low capacity
    ; card, use the command 58 for that
    SEND_COMMAND_R7(58, 0, 0)
    ; Set the block size to 512 thanks to command 16
    SEND_COMMAND_R1(16, 512, 0xFF)
    jr z, _tf_card_wait_timeout
    ; Switch to a faster clock (25MHz)
    ld a, 1
    out (SPI_REG_CLK_DIV), a
    ; Disable CRC thanks to command 59
    SEND_COMMAND_R1(59, 0, 0xFF)
    jr z, _tf_card_wait_timeout
    sra a
    ret z
_tf_card_failure:
    ld a, TFCARD_ERR_FAILURE
    ret
_tf_card_failure_pop:
    pop bc
    ld a, TFCARD_ERR_FAILURE
    ret


    ; Send ACMD41 which translates into CMD55 followed by CMD41
    ; Same signature as tf_send_command_get_reply routine
    ; At the moment, this routine is only meant to initialize non SDXC/SDHC cards
tf_card_acmd41:
    ; Try this 512 times
    ld bc, 512
_tf_card_acmd41_loop:
    push bc
    SEND_COMMAND_R1(55, 0, TF_CMD55_CRC)
    pop bc
    ; Return in case of error
    ret z
    ; Return if the command is not recognized
    cp TF_ILL_CMD
    jr z, _tf_card_acmd41_ill
    ; Send the command 41
    push bc
    ; SEND_COMMAND_R1(41, 0, 0xE5)
    SEND_COMMAND_R1(41, 0x40000000, 0x77)
    pop bc
    ; In case of a timeout, do the loop again
    jr z, _tf_card_acmd41_timeout
    ; Check if the reply is 1 (in idle)
    cp 1
    ; If not, return directly
    ret nz
    ; If yes, count this as a timeout
_tf_card_acmd41_timeout:
    dec bc
    ld a, b
    or c
    jr nz, _tf_card_acmd41_loop
    ; Timeout, Z flag is set already, simply return...
    ret
_tf_card_acmd41_ill:
    ; Make sure the X flag is NOT set
    or a
    ret


    ; Send command 1, same signature as tf_send_command_get_reply
tf_card_cmd1:
    ld b, 0
_tf_card_cmd1_loop:
    push bc
    SEND_COMMAND_R1(1, 0, TF_CMD1_CRC)
    pop bc
    ; Return in case of success
    ret nz
    djnz _tf_card_cmd1_loop
    ret


    ; Same as `tf_send_command`, but also checks whether a reply was received.
    ; In total it will send 8 bytes check for a reply from the card
    ; Parameters:
    ;   C - Number of bytes in the reply
    ; Returns:
    ;   A - Reply
    ;   Z flag set on failure (no reply), NZ on success
tf_send_command_get_reply:
    dec c
    jr z, _tf_send_command_get_reply_r1
    ; The response is composed of more than 1 byte, so in all cases, we will need to to send dummy bytes
    call tf_send_command
    ; If the command returns an error, we need to perform the dummy send and receive
    jp z, _tf_send_command_get_reply_dummy
    ; If the command already has a reply, keep it!
    push af
    call _tf_send_command_get_reply_dummy
    pop af
    ret
_tf_send_command_get_reply_r1:
    call tf_send_command
    ; De-assert CS line and return if we have already received the reply and it's a success
    jr nz, _tf_send_command_get_reply_deassert
_tf_send_command_get_reply_dummy:
    ld a, 0xFF
    ld h, a
    ld l, a
    ld d, a
    ld e, a
    ld b, a
    ; Send command will only check the last 2 bytes,
    ; so we can check only 6 bytes when calling tf_card_get_response
    call tf_send_command
    jr nz, _tf_send_command_get_reply_deassert
    ld b, 6
    call tf_card_get_response
    ; Fall-through
_tf_send_command_get_reply_deassert:
    ; De-assert CS line, do not alter A or flags
    ld c, a
    ld a, SPI_REG_CTRL_CS_END
    out (SPI_REG_CTRL), a
    ld a, c
    ret


    ; Check for a non-0xFF response in the FIFO
    ; Parameters:
    ;   B - Max length to check
    ; Returns:
    ;   A - 0xFF on failure, repsonse value else
    ;   Z flag set on failure, NZ on success
tf_card_get_response:
    ld a, 0x88
    out (SPI_REG_RAM_LEN), a
    in a, (SPI_REG_RAM_FIFO)
    cp 0xff
    ret nz
    djnz tf_card_get_response
    ret


spi_fill_fifo_dummy:
    ld a, 0x88 ; Clear the FIFO too
    out (SPI_REG_RAM_LEN), a
    ; Use a loop to save space
    ld a, 0xff
    ld b, 0x8
_spi_fill_fifo_dummy_loop:
    out (SPI_REG_RAM_FIFO), a
    djnz _spi_fill_fifo_dummy_loop
    ret


    ; The SPI controller must be in idle mode
    ; Parameters:
    ;   A    - Command number (must be ORed with 0x40!)
    ;   DEHL - 32-bit argument
    ;   B    - CRC (bit 0 must be set!)
    ; Returns:
    ;   A - Response
    ; Alters:
    ;   A, C
tf_send_command:
    ld c, a
    ; Clear the FIFO indexes and set the number of bytes that will be loaded in the , in bytes
    ld a, 0x88  ; Clear fifo + set length to 8
    out (SPI_REG_RAM_LEN), a
    ; Retrieve the command back
    ld a, c
    out (SPI_REG_RAM_FIFO), a
    ld c, SPI_REG_RAM_FIFO
    out (c), d
    out (c), e
    out (c), h
    out (c), l
    out (c), b
    ; Fill with two dummy bytes
    ld a, 0xFF
    out (c), a
    out (c), a
    ; Start the SPI transfer
    ld a, SPI_REG_CTRL_START | SPI_REG_CTRL_CS_START
    out (SPI_REG_CTRL), a
    ; Fall-through
    ; Wait for the SPI controller to go to in Idle state, in other words, wait for the
    ; SPI controller to terminate the current transfer.
    ; Returns:
    ;   A - Reply on NZ flag
    ;   Z flag - No reply
    ; Alters:
    ;   A
spi_wait_idle:
    in a, (SPI_REG_CTRL)
    rrca    ; Check bit 0, must be 0 too
    jr c, spi_wait_idle
    ; Transaction finshed, check if we have something else than 0xFF
    ; in the last two bytes (6 bytes commands, 2 dummy bytes)
    in a, (SPI_REG_RAM_TO)
    cp 0xFF
    ret nz
    in a, (SPI_REG_RAM_TO - 1)
    cp 0xFF
    ret


    ; Read a block from the TF card.
    ; Parameters:
    ;   DEHL - 32-bit address of the block
    ;   BC - Number of bytes to read and store in the buffer (at most 512 bytes)
    ;   [rd_block_arg] - Buffer address
tf_card_read_block:
    push bc
    ; Map the SPI controller
    ld a, SPI_CONTROLLER_IDX
    out (IO_MAPPER_BANK), a
    ; Send command 17
    ld a, TF_CMD_MASK | 17
    ; The following routine asserts the CS line but doesn't deassert it
    ld b, 0
    call tf_send_command
    jr z, _tf_card_read_block_timeout
    ; A contains the reply, make sure it is 0
    or a
    jr nz, _tf_card_deassert_pop
    call spi_fill_fifo_dummy
    ; Set the next transaction length to 1
    ld a, 0x81 ; Reset indexes
    out (SPI_REG_RAM_LEN), a
    ld c, SPI_REG_CTRL
    ld e, SPI_REG_CTRL_START | SPI_REG_CTRL_CS_START
    ld d, 0xFE
_tf_card_wait_fe:
    ; Start the transfer, E contains the flags to write to the control
    ; register. C contrains the control register address.
    ; D contains the 0xFE byte.
    out (c), e
    ; Perform the transaction one by one, it may be slower (not guaranteed)
    ; but it will simplify the logic below
    in a, (SPI_REG_RAM_FROM)
    cp d
    jp nz, _tf_card_wait_fe
    ; FE received!
    ; Get the total amount of bytes to read (keep it in the stack)
    pop bc
    ; Swap B anc C since `ini` alters B
    ld d, c
    ; Divide BC by 8 and store the result in B
    ld a, c
    srl b
    rra
    srl b
    rra
    srl b
    rra
    ; Move the number of 8-byte blocks in B
    ld b, a
    ; Get the buffer in HL
    ld hl, (rd_block_arg)
    ; Use C for the data address
    ld c, SPI_REG_RAM_FIFO
    ld a, 0x88 ; Reset indexes and set the size to 8
    out (SPI_REG_RAM_LEN), a
    ; Check if we have no more 8-byte blocks to read
    ld a, b
    or a
    jr z, _tf_card_read_remaining
    ;   B - Number of 8-byte blocks to read
    ;   C - Address of SPI RAM FIFO
    ;   D - LSB of size to read
    ;   E - Start transaction flags
    ;   HL - Data destination
_tf_card_read_full:
    ld a, e
    out (SPI_REG_CTRL), a
    ld a, b
    ; Read the received byte
    ini
    ini
    ini
    ini
    ini
    ini
    ini
    ini
    ; Restore B
    ld b, a
    ; Derement the number of 8-byte block to read
    djnz _tf_card_read_full
    ; No more 8-byte blocks to read
_tf_card_read_remaining:
    ld a, d
    and 7
    jr z, _tf_card_read_success
    ld b, a
    ; Start the transfer
    ld a, e
    out (SPI_REG_CTRL), a
    ; Get the data
    inir
_tf_card_read_success:
    ; Success!
    ld a, SPI_REG_CTRL_CS_END
    out (SPI_REG_CTRL), a
    xor a
    ret
_tf_card_read_block_timeout:
    ; TODO: Wait for (more) reply
    ld a, TFCARD_ERR_TIMEOUT
_tf_card_deassert_pop:
    pop bc
    jp _tf_send_command_get_reply_deassert


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
tf_open:
tf_close:
tf_deinit:
    ; Nothing special to do in this case, return success
    xor a
    ret



    ; Get the sector out of a 32-bit address.
    ; WARNING: Made the assumption that pages are 512 bytes big!
    ; Parameters:
    ;   DEHL - 32-bit address to get the block from
    ; Returns:
    ;   DEHL - 32-bit block address, accounting for the LBA start!
    ; Alters:
    ;   DE, HL
tf_get_sector:
    ; Calculate the block to read (DEHL / 512) and store it in `_tf_block`
    srl d
    rr  e
    rr  h
    ; DEH contains the block to read, put it in DEHL
    ld l, h
    ld h, e
    ld e, d
    ld d, 0
    ; Add _tf_start_lba to DEHL
    push bc
    ld bc, (_tf_start_lba)
    add hl, bc
    ld bc, (_tf_start_lba + 2)
    ex de, hl
    adc hl, bc
    ex de, hl
    pop bc
    ret

    ; Get the remaining sector size from a physical address
    ; Parameters:
    ;   HL - Bottom 16-bit address of a physical address
    ; Returns:
    ;   HL - Remaining size in the sector (1-511)
    ; Alters:
    ;   A, HL
tf_remaining_sector_size:
    ; Negate L and invert H's bit 1 (that's the equivalent of HL = 512 - (HL & 511))
    ld a, l
    cpl
    ld l, a
    ; Invert H's bit 0, set the rest to 0
    ld a, h
    cpl
    and 1
    ld h, a
    inc hl
    ret


    ; Calculate the minimum between HL and BC
    ; Parameters:
    ;   HL - Remaining size
    ;   BC - Requested size
    ; Returns:
    ;   BC - Minimum between BC and HL
    ; Alters:
    ;   BC
tf_min:
    ld a, b
    cp h
    ; On carry, H is bigger than B
    ret c
    jr nz, _hl_smaller
    ld a, c
    cp l
    ; L is bigger than C
    ret c
_hl_smaller:
    ld b, h
    ld c, l
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
tf_read:
    ; Check if the TF is accessed as a disk or a block (not implemented)
    or a
    jp nz, tf_not_implemented
    ; Save the parameters temporarily
    ld (_tf_buffer), de
    ld (_tf_total_size), bc
    ; Prepare the parameter for `read_block` function
    ld hl, rd_buf
    ld (rd_block_arg), hl
    ; Get the upper 32-bit of the address to read in DEHL
    pop de
    pop hl
    ; Check if the address is aligned on a sector size (512), A is 0 already
    ; If that's the case, we can optimize and use the user buffer directly
    or l
    jr nz, tf_read_not_aligned
    bit 0, h
    jr z, tf_read_address_aligned
tf_read_not_aligned:
    ; Address is not aligned read the current sector in a temporary buffer that
    ; will be copid back to the user provided buffer.
    ; Keep the lower 16-bit address on the stack.
    push hl
    ld (_tf_offset_low), hl
    ; Get the sector address in DEHL
    call tf_get_sector
    ; The size of the data to read is the minimum between given size and the remaining size
    ; on the current sector. Calculate the remaining part of the sector.
    ex (sp), hl
    ; Put the sector's remaining size in HL
    call tf_remaining_sector_size
    ; Put the minimum between the remaining size and the size requested by the user in BC
    call tf_min
    ; Get back the block address from the top of the stack, discard remaining sector size
    pop hl
    ; Size of the data to read in BC (the rest will be ignored)
    ; Destination buffer it in `rd_block_arg` too.
    push hl
    push de
    push bc ; Amount of bytes to read from the sector (not necessarily from the beginning!)
    ld bc, 512
    call tf_card_read_block
    ; Check for errors during the read block
    or a
    jr nz, _tf_read_error_pop
    ; Calculate the offset to copy from (HL & 511) + rd_buf
    ld bc, rd_buf
    ; Only keep H's lowest bit
    ld hl, (_tf_offset_low)
    ld a, h
    and 1
    ld h, a
    add hl, bc
    ; Source buffer in HL, get back the destination in DE
    ld de, (_tf_buffer)
    ; Get the size to read from the stack but keep it on the stack
    pop bc
    push bc
    ldir
    pop bc
    ; Subtract this amount of bytes to the remaining buffer size
    ld hl, (_tf_total_size)
    or a
    sbc hl, bc
    ; If not 0, we still have to read aligned sectors
    jr nz, tf_read_now_aligned
    ; Return success, BC contains the number of bytes read
    pop de
    pop hl
    xor a
    ret
_tf_read_error_pop:
    pop bc
    pop de
_tf_read_error_pop_once:
    pop hl
_tf_read_error:
    ld a, ERR_FAILURE
    ret

tf_read_now_aligned:
    ; Jump here after reding unaligned sectors, the rest is aligned
    ; HL - Remaining bytes to read
    ; DE - User buffer that will store the rest of the data
    ld (rd_block_arg), de
    ld b, h
    ld c, l
    ; Get the sector address in DEHL
    pop de
    pop hl
    jp _tf_read_address_aligned_sector_ready

tf_read_address_aligned:
    ; Jump here if the address to read is aligned on a sector size (512)
    ; The size to read is in both `_tf_size` and BC
    ; The physical address to read is in DEHL, calculate the block address
    call tf_get_sector
    ; Make the user buffer the destination now
    push hl
    ld hl, (_tf_buffer)
    ld (rd_block_arg), hl
    pop hl
_tf_read_address_aligned_sector_ready:
    ; [rd_block_arg] - User buffer
    ; DEHL - Block address
    ; BC - Bytes to read
    ; [_tf_size] - Same as BC
    ; Store in B the number of blocks to read, divide BC by 512
    push bc
    srl b
    jr z, _tf_read_remaining
    ; If B is 0, we have no full sector to read
    call tf_card_read_multiple_blocks
    or a
    jr nz, _tf_read_error_pop_once
_tf_read_remaining:
    ; Check if there are some byes remaining (BC = BC & 511)
    pop bc
    ld a, b
    and 1
    ld b, a
    ; Check if BC is 0
    or c
    jr z, _tf_read_finish
    ; We still have to read some bytes (< 512), user buffer is valid
    ; DEHL points to the next sector in TF card, rd_block_arg contains
    ; the valid user buffer.
    ; BC contains the valid remaining size
    call tf_card_read_block
    or a
    jr nz, _tf_read_error
_tf_read_finish:
    ; Return success
    xor a
    ld bc, (_tf_total_size)
    ret

    ; Parameters:
    ;   DEHL - Block address to read
    ;   B - Number of blocks to read
    ;   [rd_block_arg] - Destination buffer
    ; Returns:
    ;   A - 0 on success, error code else
tf_card_read_multiple_blocks:
    ; Size of the data to read (the rest will be ignored)
    push bc
    push hl
    push de
    ld bc, 512
    call tf_card_read_block
    pop de
    pop hl
    pop bc
    or a
    ret nz
    ; Increment the block address to read
    inc hl
    ; Check for carry (<=> HL == 0)
    ld a, h
    or l
    jr nz, _multiple_blocks_loop_no_carry
    inc de
_multiple_blocks_loop_no_carry:
    ; Increment the buffer by 512
    ld a, (rd_block_arg + 1)
    add 2
    ld (rd_block_arg + 1), a
    ; Success, decrement the number of blocks to process
    djnz tf_card_read_multiple_blocks
    xor a
    ret




tf_seek:
tf_ioctl:
tf_not_implemented:
    ld a, ERR_NOT_IMPLEMENTED
    ret

    ; API: Same as the read routine but for write. Not supported for CF (yet?).
tf_write:
    or a
    ld a, ERR_READ_ONLY
    ; Directly return if the stack is cleaned
    ret nz
    ; Clean the stack
    pop hl
    pop hl
    ret



    SECTION KERNEL_BSS

    ; Temporary save area
_tf_offset_low: DEFS 2
_tf_buffer: DEFS 2
_tf_total_size: DEFS 2
_tf_block: DEFS 3
_tf_start_lba: DEFS 4

    ; Parameters related to block read
rd_block_arg: DEFS 2
rd_buf: DEFS 512
    ; Marks whether the inserted tf card is following the v2 specification or not
tf_old_spec: DEFB 0

    SECTION KERNEL_DRV_VECTORS
_tf_driver:
NEW_DRIVER_STRUCT("TFC0", \
                  tf_init, \
                  tf_read, tf_write, \
                  tf_open, tf_close, \
                  tf_seek, tf_ioctl, \
                  tf_deinit)