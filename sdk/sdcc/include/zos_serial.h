/* SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

/**
 * This file represents the Serial interface.
 * THIS INTERFACE IS SUBJECT TO CHANGE.
 */


/**
 * IOCTL commands for the serial device.
 */
typedef enum {
    SERIAL_CMD_GET_ATTR = 0x80,
    SERIAL_CMD_SET_ATTR,

    SERIAL_CMD_GET_BAUDRATE,
    SERIAL_CMD_SET_BAUDRATE,

    SERIAL_GET_TIMEOUT,
    SERIAL_SET_TIMEOUT,

    SERIAL_GET_BLOCKING,
    SERIAL_SET_BLOCKING,

    SERIAL_CMD_LAST
} ser_cmd_t;


/**
 * Attributes bitmap to use with SERIAL_CMD_GET_ATTR/SERIAL_CMD_SET_ATTR commands
 */
#define SERIAL_ATTR_MODE_RAW    (1 << 0)
#define SERIAL_ATTR_RSVD1       (1 << 1)
#define SERIAL_ATTR_RSVD2       (1 << 2)
#define SERIAL_ATTR_RSVD3       (1 << 3)
#define SERIAL_ATTR_RSVD4       (1 << 4)
#define SERIAL_ATTR_RSVD5       (1 << 5)
#define SERIAL_ATTR_RSVD6       (1 << 6)
#define SERIAL_ATTR_RSVD7       (1 << 7)
