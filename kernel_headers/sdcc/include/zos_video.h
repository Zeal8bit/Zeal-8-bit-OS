/* SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <stdint.h>

/**
 * Defines from video.asm/video_h.asm
 */
#define VID_MODE_TEXT_640           0
#define VID_MODE_TEXT_320           1
#define VID_MODE_GFX_640_8BIT       4
#define VID_MODE_GFX_320_8BIT       5
#define VID_MODE_GFX_640_4BIT       6
#define VID_MODE_GFX_320_4BIT       7

// Save the current cursor position (single save only)
#define IO_TEXT_SAVE_CURSOR_BIT     7
// Restore the previously saved position
#define IO_TEXT_RESTORE_CURSOR_BIT  6
#define IO_TEXT_AUTO_SCROLL_X_BIT   5
#define IO_TEXT_AUTO_SCROLL_Y_BIT   4
// When the cursor is about to wrap to the next line (maximum amount of characters sent
// to the screen), this flag can wait for the next character to come before resetting
// the cursor X position to 0 and potentially scroll the whole screen.
// Useful to implement an eat-newline fix.
#define IO_TEXT_WAIT_ON_WRAP_BIT    3
// On READ, tells if the previous PRINT_CHAR (or NEWLINE) triggered a scroll in Y
// On WRITE, makes the cursor go to the next line
#define IO_TEXT_SCROLL_Y_OCCURRED   0
#define IO_TEXT_CURSOR_NEXTLINE     0

#define DEFAULT_VIDEO_MODE          VID_MODE_TEXT_640
#define DEFAULT_CURSOR_BLINK        30
#define DEFAULT_TEXT_CTRL           (1 << IO_TEXT_AUTO_SCROLL_Y_BIT | 1 << IO_TEXT_WAIT_ON_WRAP_BIT)

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

    /* Clear the screen and reposition the cursor at the top left. */
    CMD_CLEAR_SCREEN,

    /* Resets the screen to the same state as on boot up */
    CMD_RESET_SCREEN, 

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
