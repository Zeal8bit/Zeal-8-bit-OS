; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "errors_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "pio_h.asm"
        INCLUDE "i2c_h.asm"
        INCLUDE "interrupt_h.asm"
        INCLUDE "time_h.asm"

        EXTERN zos_sys_remap_de_page_2
        EXTERN zos_date_init

        ; Mask used to get the value from SDA input pin
        DEFC SDA_INPUT_MASK = 1 << IO_I2C_SDA_IN_PIN

        ; Address for the I2C RTC device
        DEFC I2C_RTC_ADDRESS = 0x68

        ; Default value for other pins than I2C ones. This is used to output a
        ; value on the I2C without sending garbage on the other lines (mainly UART)
        DEFC PINS_DEFAULT_STATE = IO_PIO_SYSTEM_VAL & ~(1 << IO_I2C_SDA_OUT_PIN | 1 << IO_I2C_SCL_OUT_PIN)

        SECTION KERNEL_DRV_TEXT
        ; PIO has been initialized before-hand
i2c_init:
        ; Initialize the getdate routine, which will communicate with the I2C RTC
        ld hl, i2c_setdate
        ld de, i2c_getdate
        call zos_date_init
i2c_open:
i2c_deinit:
        ; Return ERR_SUCCESS
        xor a
        ret

        ; Reset the device address when closed
i2c_close:
        xor a
        ld (_i2c_dev_addr), a
        ret

        ; Perform an I/O requested by the user application.
        ; Check the commands and parameters for the I2C in "include/i2c_h.asm" file.
        ; Parameters:
        ;       B - Dev number the I/O request is performed on.
        ;       C - Command macro, any of the following macros:
        ;           * I2C_DEVICE_ADDR
        ;           * I2C_WRITE_READ
        ;       E  - The device address in case of a I2C_DEVICE_ADDR command
        ;       DE - Pointer to i2c_transfer_t structure in case of a I2C_WRITE_READ command:
        ;            The pointers in the structure must be in the same 16KB virtual page.
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, BC, DE, HL
i2c_ioctl:
        ; Check that the command number is correct
        ld a, c
        or a
        jp z, _i2c_ioctl_set_addr
        dec a
        jp z, _i2c_ioctl_write_read
        ; Invalid/unsupported/unimplemented command
        ld a, ERR_NOT_SUPPORTED
        ret

_i2c_ioctl_set_addr:
        ; Only 7-bit addresses are supported, check that it's correct
        bit 7, e
        jp nz, i2c_invalid_param
        ld a, e
        ld (_i2c_dev_addr), a
        ; Return success
        xor a
        ret

_i2c_ioctl_write_read:
    IF CONFIG_KERNEL_TARGET_HAS_MMU
        ; In the case of ioctl, we know that after returning, we will almost directly
        ; return to the user space, where its virtual pages will be reset. As such, we
        ; don't need to save the current MMU pages here and restore them.
        ; Let's just map the parameter address (DE)
        call zos_sys_remap_de_page_2
    ENDIF
        ; Now DE is accessible for sure
        ; Dereference the size of the write and read buffers respectively
        ex de, hl
        ld b, (hl)
        inc hl
        ld c, (hl)
        inc hl
        ; Make sure the sizes are not 0!
        ld a, b
        or a
        jp z, i2c_invalid_param
        ld a, c
        or a
        jp z, i2c_invalid_param
        ; Dereference write buffer address in DE (we will swap afterwards)
        ld e, (hl)
        inc hl
        ld d, (hl)
        inc hl
        ; Dereference read buffer address in HL
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        ex de, hl
        ; Make sure both DE and HL are in the same MMU page, check the highest 2 bits
        ld a, d
        xor h
        ; If both are in the same page, two bits of A are now 00
        and 0xc0
        jp nz, i2c_invalid_param
        ; Perform a write-read operation, the parameters are:
        ;   A - 7-bit device address
        ;   HL - Write buffer (bytes to write)
        ;   DE - Read buffer (bytes read from the bus)
        ;   B - Size of the write buffer
        ;   C - Size of the read buffer
        ; Returns:
        ;   A - 0: ERR_SUCCESS
        ;       1: No device responded, ERR_FAILURE
        ld a, (_i2c_dev_addr)
        jp i2c_write_read_device


        ; ----- Private routines -----;
        ; Get the current date
        ; Parameters:
        ;       DE - Address to a date structure to fill. Guaranteed not NULL and mapped.
i2c_getdate:
        ; Save the user's buffer first
        push de
        ; The work buffer is bigger than the date structure, let's use it.
        ld hl, _driver_buffer
        ld (hl), 0
        ld de, _driver_buffer + 1
        ; Perform a write followed by a read on the bus
        ; Parameters:
        ;   A - 7-bit device address
        ;   HL - Write buffer (bytes to write)
        ;   DE - Read buffer (bytes read from the bus)
        ;   B - Size of the write buffer
        ;   C - Size of the read buffer
        ld a, I2C_RTC_ADDRESS
        ld b, 1 ; Write 1 byte, the register 0
        ld c, 8 ; Read 8 bytes
        call i2c_write_read_device
        ; Pop the user buffer in HL
        pop hl
        ; Check if an error occurred
        or a
        ret nz
        ; We have to fill HL with data in DE, the first date field is year, hardcode 20xx first
        ld (hl), 0x20
        inc hl
        ; DE contains the register read from the RTC, they are in reverse order (seconds, minutes, etc...)
        ld de, _driver_buffer + 1 + 6
        ; We cannot use LDI or LDD, because HL must be incremented while DE must be decremented
        ld b, 6
_getdate_loop:
        ld a, (de)
        ld (hl), a
        dec de
        inc hl
        djnz _getdate_loop
        ; We need to adjust the seconds to remove the upper bit (CH enable)
        ld a, (de)
        and 0x7f
        ld (hl), a
        ; We also need to adjust the hours
        dec hl
        dec hl
        ld a, (hl)
        ; Adjust only for PM/AM mode, the register is as is:
        ; Bits: 7     6       5       4      3 2 1 0
        ;       0   24/12   AM/PM   10Hour |  Hours
        bit 6, a
        jr nz, _getdate_adjust_hours
        ; No need to adjust, we can return success
        xor a
        ret
_getdate_adjust_hours:
        ; Backup A, after removing the bit 6, in B
        and 0x3f
        ld b, a
        ; Add 0x12 to the current time if PM is set, two exceptions though:
        ;  * 12am which becomes 00
        ;  * 12pm which becomes 12
        ; Thus, invert the AM/PM bit for them
        and 0x1f
        cp 0x12
        ; Restore A before jumping (or not)
        ld a, b
        jr nz, _getdate_no_12
        ; Invert AM/PM bit
        xor 0x20
_getdate_no_12:
        ; Only add 0x12 if PM (1)
        bit 5, a
        jr z, _getdate_no_adjust
        and 0x1f        ; Only keep the hours
        add 0x12        ; Add 12 in hex (BCD)
        daa
        ; Check if result is 24
        cp 0x24
        jr nz, _getdate_no_adjust
        ; Reset A else
        xor a
_getdate_no_adjust:
        ld (hl), a
        ; Return success
        xor a
        ret


        ; Set the current date
        ; Parameters:
        ;       DE - Address of the date structure to set. Guaranteed not NULL and mapped.
i2c_setdate:
        ; Save the user's buffer first
        push de
        ; Make it point to the 'seconds'
        ex de, hl
        ld bc, DATE_STRUCT_SIZE - 1
        add hl, bc
        ex de, hl
        ; The work buffer is bigger than the date structure, let's use it.
        ld hl, _driver_buffer
        ld (hl), 0
        inc hl
        ; Get the seconds, remove the highest bit and store it in the buffer
        ld a, (de)
        and 0x7f
        ld (hl), a
        ; For the rest, do not check anything to simplify the code
        ld b, c
        dec b
_i2c_setdate_loop:
        inc hl
        dec de
        ld a, (de)
        ld (hl), a
        djnz _i2c_setdate_loop
        ; Write bytes on the bus to the specified device
        ;   A - 7-bit device address
        ;   HL - Buffer to write on the bus
        ;   B - Size of the buffer
        ; Returns:
        ;   A - 0: Success
        ;       1: No device responded
        ;       2: Device stopped responding during transmission (NACK received)
        ld a, I2C_RTC_ADDRESS
        ld b, DATE_STRUCT_SIZE + 1
        ld hl, _driver_buffer
        call i2c_write_device
        pop de
        ret

        ; Read bytes from the I2C.
        ; Parameters:
        ;       DE - Destination buffer, smaller than 16KB, not cross-boundary, guaranteed to be mapped.
        ;       BC - Size to read in bytes.
        ;       A  - Should be DRIVER_OP_NO_OFFSET here.
        ; Returns:
        ;       A  - ERR_SUCCESS if success, error code else
        ;       BC - Number of bytes read.
        ; Alters:
        ;       This function can alter any register.
i2c_read:
        ; Check that the size is not too big
        ld a, d
        or a
        jp nz, i2c_invalid_param
        ; Check that the size is not 0 either
        or e
        jp z, i2c_invalid_param
        ; Prepare the parameters to read a device:
        ;   A - 7-bit device address
        ;   HL - Buffer to store the bytes read
        ;   BC - Size of the buffer
        ; Returns:
        ;   A - ERR_SUCCESS on success, ERR_FAILURE (No device responded) else
        ld a, (_i2c_dev_addr)
        ex de, hl
        jp i2c_read_device

i2c_write:
        ; Check that the size is not too big
        ld a, d
        or a
        jp nz, i2c_invalid_param
        ; Check that the size is not 0 either
        or e
        jp z, i2c_invalid_param
        ; Write bytes on the bus to the specified device
        ;   A - 7-bit device address
        ;   HL - Buffer to write on the bus
        ;   B - Size of the buffer
        ; Returns:
        ;   A - 0: Success
        ;       1: No device responded
        ;       2: Device stopped responding during transmission (NACK received)
        ld a, (_i2c_dev_addr)
        ld b, c
        ex de, hl
        call i2c_write_device
        or a
        ret z
        ld a, ERR_FAILURE
        ret

        ; No such thing as seek for the I2C
i2c_seek:
        ld a, ERR_NOT_SUPPORTED
        ret

        ; ---- Non-API related routines ----
i2c_invalid_param:
        ld a, ERR_INVALID_PARAMETER
        ret

        ; Send a single byte on the bus (and check ACK)
        ; Parameters:
        ;   A - Byte to send
        ; Returns:
        ;   A - SDA Pin state
        ;   NZ Flag - NACK
        ;   Z Flag - ACK received
        ; Alters:
        ;   A, DE
i2c_send_byte:
        push bc
        ld b, 8
        ld c, PINS_DEFAULT_STATE
        ; Prepare the byte to send
    REPT IO_I2C_SDA_OUT_PIN
        rlca
    ENDR
        ld e, a
        ; D represent the mask to retrieve the SDA line output data
        ld d, 1 << IO_I2C_SDA_OUT_PIN
        ; A represent the current value of SDA, 0 to begin with
        xor a
_i2c_send_byte_loop:
        rlc e

        ; Set SCL low, keep SDA to the current value
        or c
        out (IO_PIO_SYSTEM_DATA), a

        ; Prepare the next bit to send in the PINS_STATE
        ld a, e
        and d
        or c    ; or with PINS_DEFAULT_STATE

    IFNDEF I2C_NO_LIMIT
        ; In order to achieve a duty cycle of 50% with a period of 5us, let's add the following
        bit 0, a
    ENDIF

        ; Set SDA state in PIO, set SCL to low at the same time
        ; SCL is already 0 because PINS_DEFAULT_STATE sets it to 0
        out (IO_PIO_SYSTEM_DATA), a

        ; Set SCL back to high: SDA must not change.
        or 1 << IO_I2C_SCL_OUT_PIN
        out (IO_PIO_SYSTEM_DATA), a

        ; Save only the current SDA value in A
        and d

    IFNDEF I2C_NO_LIMIT
        ; In order to achieve a duty cycle of 50% with a period of 5us, let's add the following
        jp $+3
    ENDIF

        ; SDA is not allowed to change here as SCL is high
        djnz _i2c_send_byte_loop
        ; End of byte transmission, A contains the last value sent

        ; Need to check ACK: set SCL to low, do not modify SDA (A)
        ; We could use `or c`, but we want to operation to last a bit longer
        or PINS_DEFAULT_STATE
        out (IO_PIO_SYSTEM_DATA), a

        ; SDA MUST be set to 1 to activate the open-drain output!
        ld a, PINS_DEFAULT_STATE | (1 << IO_I2C_SDA_OUT_PIN)
        out (IO_PIO_SYSTEM_DATA), a

        ; Wait a bit to have a 5us period
    IFNDEF I2C_NO_LIMIT
        jr $+2
    ENDIF

        ; Put SCL high again
        ld a, PINS_DEFAULT_STATE | (1 << IO_I2C_SDA_OUT_PIN) | (1 << IO_I2C_SCL_OUT_PIN)
        out (IO_PIO_SYSTEM_DATA), a

        ; Read the reply from the device
        in a, (IO_PIO_SYSTEM_DATA)
        and SDA_INPUT_MASK

        pop bc
        ret


        ; Receive a byte on the bus (perform ACK if needed)
        ; Parameters:
        ;   A - 0: ACK, 1: NACK
        ; Returns:
        ;   A - Byte received
i2c_receive_byte:
        push bc
        push hl
        ld b, 8
        ld c, IO_PIO_SYSTEM_DATA
        ; Contains ACK or NACK
        ld d, a
        ; Contains the result
        xor a
        ld h, SDA_INPUT_MASK
        ld l, PINS_DEFAULT_STATE | (1 << IO_I2C_SDA_OUT_PIN)
_i2c_receive_byte_loop:
        ; A contains the future content of E, which needs to be shifted once
        ; to allow a new bit to come.
        rlca

        ; Set SCL low, and SDA high (high impedance)
        out (c), l

        ld e, a

        IFNDEF I2C_NO_LIMIT
        ; Without a delay, SCL will stay low during less than 5us. Let's balance it by delaying a bit.
        push af
        pop af
        nop
        ENDIF

        ; Set SCL back to high
        ld a, PINS_DEFAULT_STATE | (1 << IO_I2C_SDA_OUT_PIN) | (1 << IO_I2C_SCL_OUT_PIN)
        out (c), a

        ; SDA is not allowed to change here as SCL is high
        ; Get the value of SDA here
        in a, (c)
        and h
        add e
        ; Loop again until we don't have any remaining bit
        djnz _i2c_receive_byte_loop

        ; End of byte transmission, set result in E
        ld e, a

        ; SDA is in high-impedance here, set clock to low first
        out (c), l

        ; Check if we need to ACK. D is either 0, ACK, either 1, NACK.
        ld a, d
        REPT IO_I2C_SDA_OUT_PIN
        rlca
        ENDR

        ; Output value of SDA first, while SCL is still low
        or PINS_DEFAULT_STATE
        out (c), a

        ; Add the flag to put SCL to 1
        or 1 << IO_I2C_SCL_OUT_PIN
        out (c), a

        ; Return the byte received, needs to be shifted
        ld a, e
        REPT IO_I2C_SDA_IN_PIN
        rrca
        ENDR

        pop hl
        pop bc
        ret


        ; Perform a START on the bus. SCL MUST be high when calling this routine
        ; Parameters:
        ;   None
        ; Returns:
        ;   None
        ; Alters:
        ;   C
i2c_perform_start:
        ld c, a
        ; Output a start bit by setting SDA to LOW. SCL must remain HIGH.
        ld a, PINS_DEFAULT_STATE | (1 << IO_I2C_SCL_OUT_PIN) | (0 << IO_I2C_SDA_OUT_PIN)
        out (IO_PIO_SYSTEM_DATA), a
        ld a, c
        ret
i2c_perform_repeated_start:
        ; Set SCL to low, set SDA to high
        ld c, a
        ld a, PINS_DEFAULT_STATE | (1 << IO_I2C_SDA_OUT_PIN)
        out (IO_PIO_SYSTEM_DATA), a
        ; Set SCL to high, without modifying SDA
        or 1 << IO_I2C_SCL_OUT_PIN
        out (IO_PIO_SYSTEM_DATA), a
        ; Issue a regular start
        ; Output a start bit by setting SDA to LOW. SCL must remain HIGH.
        ld a, PINS_DEFAULT_STATE | (1 << IO_I2C_SCL_OUT_PIN)
        out (IO_PIO_SYSTEM_DATA), a
        ld a, c
        ret

        ; Perform a STOP on the bus. SCL MUST be high when calling this routine
        ; Parameters:
        ;   None
        ; Returns:
        ;   None
        ; Alters:
        ;   C
i2c_perform_stop:
        ld c, a
        in a, (IO_PIO_SYSTEM_DATA)
        ; Set SCL to low while keeping SDA value
        and  ~(1 << IO_I2C_SCL_OUT_PIN)
        out (IO_PIO_SYSTEM_DATA), a
        ; Put both SCL and SDA to low
        ld a, PINS_DEFAULT_STATE
        out (IO_PIO_SYSTEM_DATA), a
        ; Set SCL to high
        or 1 << IO_I2C_SCL_OUT_PIN
        out (IO_PIO_SYSTEM_DATA), a
        ; Set SDA to high
        or 1 << IO_I2C_SDA_OUT_PIN
        out (IO_PIO_SYSTEM_DATA), a
        ld a, c
        ret

        ; Write bytes on the bus to the specified device
        ; Parameters:
        ;   A - 7-bit device address
        ;   HL - Buffer to write on the bus
        ;   B - Size of the buffer
        ; Returns:
        ;   A - 0: Success
        ;       -1: No device responded
        ;       positive value: Device stopped responding during transmission (NACK received)
        ; Alters:
        ;   A, HL
        PUBLIC i2c_write_device
i2c_write_device:
        push bc
        push de
        ; Set no secondary/register buffer
        ld c, 0
        call i2c_write_double_buffer
        pop de
        pop bc
        ret

        ; Write bytes on the bus to the specified device. A secondary buffer can be passed.
        ; This secondary buffer will be sent first, it can contain the register address.
        ; Parameters:
        ;   A - 7-bit device address
        ;   DE - Register address buffer
        ;   C  - Size of the register address buffer, can be 0, which ignores DE
        ;   HL - Buffer to write on the bus
        ;   B - Size of the buffer, must not be 0
        ; Returns:
        ;   A - 0: Success
        ;       -1: No device responded
        ;       positive value: Device stopped responding during transmission (NACK received)
        ; Alters:
        ;   A, BC, DE, HL
        PUBLIC i2c_write_double_buffer
i2c_write_double_buffer:
        push hl
        ex de, hl   ; Put the register buffer in HL
        push bc

        ; Making the write device address in A (left shift + 0)
        sla a

        ; Start signal and send address
        call i2c_perform_start
        call i2c_send_byte
        ; If not zero, NACK was received, abort
        ld a, 0xff
        ; Get back both buffer sizes in BC before checking errors
        pop bc
        jp nz, _i2c_write_double_nack

        ld a, c
        or a
        jp z, _i2c_write_double_no_register
_i2c_write_double_register:
        ld a, (hl)
        inc hl
        ; BC are both preserved across this function call
        call i2c_send_byte
        ; If not zero, NACK was received, abort.
        jr nz, _i2c_write_double_nack
        dec c
        jp nz, _i2c_write_double_register
_i2c_write_double_no_register:
        ; Get back the data buffer from the stack
        pop hl
        ; Start reading and sending the bytes
_i2c_write_double_byte:
        ld a, (hl)
        inc hl
        ; BC are both preserved across this function call
        call i2c_send_byte
        ; If not zero, NACK was received, abort.
        jr nz, _i2c_write_double_nack_no_pop
        djnz _i2c_write_double_byte

        ; A should be 0 at the end to show success
        xor a
        jp i2c_perform_stop
_i2c_write_double_nack:
        pop hl
_i2c_write_double_nack_no_pop:
        ; Doesn't alter A (return value)
        call i2c_perform_stop
        ret


        ; Read bytes from a device on the bus
        ; Parameters:
        ;   A - 7-bit device address
        ;   HL - Buffer to store the bytes read
        ;   BC - Size of the buffer
        ; Returns:
        ;   A - 0: Success
        ;       -1: No device responded
        ; Alters:
        ;   A, HL
        PUBLIC i2c_read_device
i2c_read_device:
        ; In order to optimize the size of this routine, C will be used as a
        ; temporary storage for device address and error code
        push bc
        push de

        ; Making the read device address in A (left shift + 1)
        scf
        rla

        ; Save C in register E since start uses C
        ld e, c
        ; Start signal and send address
        call i2c_perform_start
        ld c, e
        ; Send the device address
        call i2c_send_byte
        ; If not zero, NACK was received, abort
        ld a, 0xff
        jr nz, _i2c_read_device_address_nack

        ; Run the following loop for BC - 1 (sending an ACK at the end)
        dec bc
        ld a, b
        or c
        jr z, _i2c_read_device_byte_end
_i2c_read_device_byte:
        ; Set A to 0 (ACK)
        xor a
        ; BC and HL are both preserved across this function call
        call i2c_receive_byte
        ld (hl), a
        inc hl
        dec bc
        ld a, b
        or c
        jp nz, _i2c_read_device_byte
_i2c_read_device_byte_end:
        ; Set A to 1 (NACK)
        inc a
        call i2c_receive_byte
        ld (hl), a

        ; Success, set A to 0
        xor a
_i2c_read_device_address_nack:
        ; Send stop signal in ANY case
        call i2c_perform_stop
        pop de
        pop bc
        ret

        ; Perform a write followed by a read on the bus
        ; Parameters:
        ;   A - 7-bit device address
        ;   HL - Write buffer (bytes to write)
        ;   DE - Read buffer (bytes read from the bus)
        ;   B - Size of the write buffer (0 for 256)
        ;   C - Size of the read buffer (0 for 256)
        ; Returns:
        ;   A - 0: Success
        ;       -1: No device responded
        ; Alters:
        ;   A, HL
        PUBLIC i2c_write_read_device
i2c_write_read_device:
        ; In order to optimize the size of this routine, C will be used as a
        ; temporary storage for device address and error code
        push bc
        push de

        ; Making the write device address in A (left shift + 0)
        sla a
        ; Save AF for the device address
        push af

        ; Start signal and send address
        call i2c_perform_start
        ; Send the device address
        call i2c_send_byte
        ; If not zero, NACK was received, abort
        jr nz, _i2c_write_read_device_address_nack

        ; Start sending the bytes
_i2c_write_read_write_device_byte:
        ld a, (hl)
        inc hl
        ; BC are both preserved across this function call
        call i2c_send_byte
        ; If not zero, NACK was received, abort
        jr nz, _i2c_write_read_device_address_nack
        djnz _i2c_write_read_write_device_byte

        ; Bytes were sent successfully. Issue a repeated start with the read address.
        pop af

        ; Making the read device address in A. A has already been shifted left.
        inc a

        ; Start signal and send address
        call i2c_perform_repeated_start
        ; Send the (read) device address
        call i2c_send_byte
        ; If not zero, NACK was received, abort
        jp nz, _i2c_write_read_device_address_nack_no_pop

        ; Before reading the bytes, retrieve DE and BC from the stack.
        ; Put DE in HL. Both HL and BC shall be saved back on the stack.
        pop hl
        pop bc
        push bc
        push hl
        ; Argument (DE) is in HL, put C (read size) argument in B
        ld b, c
        ; Run the following loop for B - 1 (sending an ACK at the end)
        dec b
        jp z, _i2c_write_read_read_device_byte_end
_i2c_write_read_read_device_byte:
        ; Set A to 0 (ACK)
        xor a
        ; B and HL are both preserved across this function call
        call i2c_receive_byte
        ld (hl), a
        inc hl
        djnz _i2c_write_read_read_device_byte
_i2c_write_read_read_device_byte_end:
        ; Set A to 1 (NACK)
        ld a, 1
        call i2c_receive_byte
        ld (hl), a

        ; Everything went well, stop signal
        xor a
        jp _i2c_write_read_device_end
_i2c_write_read_device_address_nack:
        pop af
_i2c_write_read_device_address_nack_no_pop:
        ld a, 0xff
_i2c_write_read_device_end:
        call i2c_perform_stop
        pop de
        pop bc
        ret


        SECTION DRIVER_BSS
_i2c_dev_addr: DEFS 1
_driver_buffer: DEFS 32

        SECTION KERNEL_DRV_VECTORS
NEW_DRIVER_STRUCT("I2C0", \
                  i2c_init, \
                  i2c_read, i2c_write, \
                  i2c_open, i2c_close, \
                  i2c_seek, i2c_ioctl, \
                  i2c_deinit)