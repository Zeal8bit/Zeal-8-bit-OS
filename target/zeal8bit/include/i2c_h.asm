; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
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

        ENDIF