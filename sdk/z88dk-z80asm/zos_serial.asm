
; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    IFNDEF ZOS_SERIAL_H
    DEFINE ZOS_SERIAL_H

    ; This file represents the minimal interface for a serial driver.
    ; If any command below is not supported, the driver should return
    ; ERR_NOT_SUPPORTED.

    ; IOCTL commands the driver should implement
    DEFGROUP {
        ; Get the serial driver attributes.
        ; Parameter:
        ;   DE - Address to fill with the 16-bit attribute
        SERIAL_CMD_GET_ATTR = 0x80,        ; See attribute group below

        ; Set the serial driver attributes.
        ; Parameter:
        ;   DE - 16-bit attributes to set (NOT AN ADDRESS/POINTER)
        SERIAL_CMD_SET_ATTR,


        SERIAL_CMD_GET_BAUDRATE,
        SERIAL_CMD_SET_BAUDRATE,


        SERIAL_GET_TIMEOUT,
        SERIAL_SET_TIMEOUT,


        SERIAL_GET_BLOCKING,
        SERIAL_SET_BLOCKING,

        ; Number of commands above
        SERIAL_CMD_COUNT
    }

    ; Serial driver attribute bitmap to use with SERIAL_CMD_GET_ATTR command
    DEFGROUP {
        SERIAL_ATTR_MODE_RAW = 1 << 0,
        SERIAL_ATTR_RSVD1    = 1 << 1,
        SERIAL_ATTR_RSVD2    = 1 << 2,
        SERIAL_ATTR_RSVD3    = 1 << 3,
        SERIAL_ATTR_RSVD4    = 1 << 4,
        SERIAL_ATTR_RSVD5    = 1 << 5,
        SERIAL_ATTR_RSVD6    = 1 << 6,
        SERIAL_ATTR_RSVD7    = 1 << 7
    }

    ENDIF ; ZOS_SERIAL_H