/* SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <stdint.h>

/**
 * Helper to construct a color that can be passed to CMD_SET_COLORS command
 */
#define TEXT_COLOR(fg, bg) (void*) ((((bg) & 0xff) << 8) | (fg & 0xff))

typedef enum {
    CMD_GET_ATTR = 0,

    /* Area bound for the current mode, the parameter is zos_text_area_t* */
    CMD_GET_AREA,

    /* Get the current cursor position, the parameter is uint8_t[2], where
     * the first entry is X, the second entry is Y. They represent indexes,
     * so they start at 0. */
    CMD_GET_CURSOR_XY,

    CMD_SET_ATTR,

    /* Set the cursor position. The paramater is a 16-bit value where upper byte
     * is X coordinate and lower byte is Y coordinate. Same here, they start at 0. */
    CMD_SET_CURSOR_XY,  // Set the current cursor position,

    /* Set the current background and foreground color. When set, all the printed
     * characters following will have these colors.
     * Parameter is a 16-bit value where upper byte is the background color and the lower
     * byte is the foreground color.
     * Check the color enumeration below. */
    CMD_SET_COLORS,

    CMD_COUNT
} zos_video_cmd_t;


typedef enum {
    TEXT_COLOR_BLACK         = 0x0,
    TEXT_COLOR_DARK_BLUE     = 0x1,
    TEXT_COLOR_DARK_GREEN    = 0x2,
    TEXT_COLOR_DARK_CYAN     = 0x3,
    TEXT_COLOR_DARK_RED      = 0x4,
    TEXT_COLOR_DARK_MAGENTA  = 0x5,
    TEXT_COLOR_BROWN         = 0x6,
    TEXT_COLOR_LIGHT_GRAY    = 0x7,
    TEXT_COLOR_DARK_GRAY     = 0x8,
    TEXT_COLOR_BLUE          = 0x9,
    TEXT_COLOR_GREEN         = 0xa,
    TEXT_COLOR_CYAN          = 0xb,
    TEXT_COLOR_RED           = 0xc,
    TEXT_COLOR_MAGENTA       = 0xd,
    TEXT_COLOR_YELLOW        = 0xe,
    TEXT_COLOR_WHITE         = 0xf,
} zos_text_color_t;


typedef struct
{
    uint8_t  width;  // Maximum number of characters on one line
    uint8_t  height; // Maximum number of characters on one column
    uint16_t count;  // Number of entities on screen
} zos_text_area_t;
