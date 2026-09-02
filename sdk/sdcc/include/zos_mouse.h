/* SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

/**
 * This file represents the mouse interface.
 *
 * The mouse driver provides accumulated mouse state via the `read` syscall.
 * Open the driver with:
 *   zos_dev_t dev = open(MOUSE_DEVICE_NAME, O_RDONLY);
 *
 * Then read a zos_mouse_state_t structure:
 *   zos_mouse_state_t state;
 *   uint16_t size = sizeof(state);
 *   read(dev, &state, &size);
 *
 * On success, X and Y contain accumulated movement since last read.
 * The accumulators are reset to 0 after each read.
 */

#include <stdint.h>
#include "zos_errors.h"

/**
 * @brief Device name to use when opening the mouse driver.
 */
#define MOUSE_DEVICE_NAME "#MOUS"

/**
 * @brief Button bit constants for the `buttons` field.
 */
#define MOUSE_BTN_LEFT     (1 << 0)  /* Left button pressed */
#define MOUSE_BTN_RIGHT    (1 << 1)  /* Right button pressed */
#define MOUSE_BTN_MIDDLE   (1 << 2)  /* Middle button pressed */


/**
 * @brief Mouse state structure filled by the driver upon `read`.
 */
typedef struct {
    union {
        struct {
            uint8_t left   : 1;
            uint8_t right  : 1;
            uint8_t middle : 1;
            uint8_t rsvd3  : 1;
            uint8_t rsvd4  : 4;
        };
        uint8_t raw;
    } buttons;
    int16_t x_axis;
    int16_t y_axis;
} zos_mouse_state_t;
