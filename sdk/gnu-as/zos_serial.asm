
; SPDX-FileCopyrightText: 2024 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .equiv ZOS_SERIAL_H, 1

    ; This file represents the minimal interface for a serial driver.
    ; If any command below is not supported, the driver should return
    ; ERR_NOT_SUPPORTED.

    ; IOCTL commands the driver should implement
    ; Get the serial driver attributes.
    ; Parameter:
    ;   DE - Address to fill with the 16-bit attribute
    .equ SERIAL_CMD_GET_ATTR,     0x80        ; See attribute group below
    ; Set the serial driver attributes.
    ; Parameter:
    ;   DE - 16-bit attributes to set (NOT AN ADDRESS/POINTER)
    .equ SERIAL_CMD_SET_ATTR,     0x81
    .equ SERIAL_CMD_GET_BAUDRATE, 0x82
    .equ SERIAL_CMD_SET_BAUDRATE, 0x83
    .equ SERIAL_GET_TIMEOUT,      0x84
    .equ SERIAL_SET_TIMEOUT,      0x85
    .equ SERIAL_GET_BLOCKING,     0x86
    .equ SERIAL_SET_BLOCKING,     0x87
    ; Number of commands above
    .equ SERIAL_CMD_COUNT,        0x88


    ; Serial driver attribute bitmap to use with SERIAL_CMD_GET_ATTR command
    .equ SERIAL_ATTR_MODE_RAW, 1 << 0
    .equ SERIAL_ATTR_RSVD1,    1 << 1
    .equ SERIAL_ATTR_RSVD2,    1 << 2
    .equ SERIAL_ATTR_RSVD3,    1 << 3
    .equ SERIAL_ATTR_RSVD4,    1 << 4
    .equ SERIAL_ATTR_RSVD5,    1 << 5
    .equ SERIAL_ATTR_RSVD6,    1 << 6
    .equ SERIAL_ATTR_RSVD7,    1 << 7
