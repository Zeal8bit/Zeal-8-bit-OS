; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        IFNDEF I2C_H
        DEFINE I2C_H

        ; I2C commands
        DEFGROUP {
            I2C_DEVICE_ADDR = 0,
            I2C_WRITE_READ,
            I2C_CMD_LAST
        }

        ; Definition of i2c_transfer_t type for I2C_WRITE_READ command
        ; Both i2c_read_buffer_t and i2c_write_buffer_t must belong to the same virtual
        ; page!
        DEFVARS 0 {
                i2c_write_size_t   DS.B 1 ; Size of the write buffer, must not be 0
                i2c_read_size_t    DS.B 1 ; Size of the read buffer, must not be 0
                i2c_write_buffer_t DS.B 2 ; Virtual address of write buffer
                i2c_read_buffer_t  DS.B 2 ; Virtual address of read buffer
                i2c_transfer_end_t DS.B 1
        }


        ; Perform a write followed by a read on the bus
        ; Parameters:
        ;   A - 7-bit device address
        ;   HL - Write buffer (bytes to write)
        ;   DE - Read buffer (bytes read from the bus)
        ;   B - Size of the write buffer
        ;   C - Size of the read buffer
        ; Returns:
        ;   A - 0: Success
        ;       -1: No device responded
        ; Alters:
        ;   A, HL
        EXTERN i2c_write_read_device


        ; Read bytes from a device on the bus
        ; Parameters:
        ;   A - 7-bit device address
        ;   HL - Buffer to store the bytes read
        ;   B - Size of the buffer
        ; Returns:
        ;   A - 0: Success
        ;       -1: No device responded
        ; Alters:
        ;   A, HL
        EXTERN i2c_read_device


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
        EXTERN i2c_write_device


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
        EXTERN i2c_write_double_buffer

        ENDIF