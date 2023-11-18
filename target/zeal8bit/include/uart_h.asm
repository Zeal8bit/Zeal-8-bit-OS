; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    IFNDEF UART_H
    DEFINE UART_H

    ; UART commands, start at 0x80 to allow drivers to also handle the video commands (when UART is STDOUT)
    DEFGROUP {
        ; The attributes bits are defines below
        UART_CMD_GET_ATTR = 0x80,
        UART_CMD_SET_ATTR,

        ; The values for the baudrates are defined below
        UART_CMD_GET_BAUDRATE,
        UART_CMD_SET_BAUDRATE,

        UART_GET_TIMEOUT,
        UART_SET_TIMEOUT,

        UART_GET_BLOCKING,
        UART_SET_BLOCKING,

        UART_CMD_LAST
    }

    ; UART attributes
    DEFC UART_ATTR_MODE_RAW = 1 << 0
    DEFC UART_ATTR_RSVD1    = 1 << 1
    DEFC UART_ATTR_RSVD2    = 1 << 2
    DEFC UART_ATTR_RSVD3    = 1 << 3
    DEFC UART_ATTR_RSVD4    = 1 << 4
    DEFC UART_ATTR_RSVD5    = 1 << 5
    DEFC UART_ATTR_RSVD6    = 1 << 6
    DEFC UART_ATTR_RSVD7    = 1 << 7

    ; Baudrates for receiving bytes from the UART
    DEFC UART_BAUDRATE_57600 = 0
    DEFC UART_BAUDRATE_38400 = 1
    DEFC UART_BAUDRATE_19200 = 4
    DEFC UART_BAUDRATE_9600  = 10

    ; Default baudrate for UART
    DEFC UART_BAUDRATE_DEFAULT = UART_BAUDRATE_57600

    ENDIF ; UART_H
