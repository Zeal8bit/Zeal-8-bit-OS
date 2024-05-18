; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    IFNDEF KEYBOARD_H
    DEFINE KEYBOARD_H

    INCLUDE "drivers/keyboard_h.asm"

    ; Macros for keyboard
    DEFC KB_IO_ADDRESS = 0xE8

    DEFGROUP {
        BASE_SCAN_TABLE,
        UPPER_SCAN_TABLE,
        SPECIAL_SCAN_TABLE,
        EXT_SCAN_TABLE,
    }

    DEFC KB_EVT_PRESSED = 0
    DEFC KB_EVT_RELEASED = 1

    DEFC KB_PRINTABLE_CNT = 0x60
    DEFC KB_SPECIAL_START = 0x66	; Between 0x60 and 0x66, nothing special
    DEFC KB_CAPSL_SCAN 	  = 0x58
    DEFC KB_EXTENDED_SCAN = 0xe0	; Extended characters such as keypad or arrows
    DEFC KB_RELEASE_SCAN  = 0xf0
    DEFC KB_RIGHT_ALT_SCAN  = 0x11
    DEFC KB_RIGHT_CTRL_SCAN = 0x14
    DEFC KB_LEFT_SUPER_SCAN = 0x1f
    DEFC KB_NUMPAD_DIV_SCAN = 0x4a
    DEFC KB_NUMPAD_RET_SCAN = 0x5a
    DEFC KB_PRT_SCREEN_SCAN = 0x12	; When Print Screen is received, the scan is 0xE0 0x12
    DEFC KB_MAPPED_EXT_SCANS = 0x69 ; Extended characters which scan code is 0xE0 0x69 and above
                                    ; are treated with a mapped array

    ; Macros for modifier key flags
    DEFC KB_FLAG_KEYP_BIT  = 0x7
    DEFC KB_FLAG_CTRL_BIT  = 0x6
    DEFC KB_FLAG_ALT_BIT   = 0x5
    DEFC KB_FLAG_SHIFT_BIT = 0x4

    DEFC KB_FLAG_MODE_MASK = 0b111
    DEFC KB_BLK_MODE_MASK  = 0b100
    DEFC KB_BUF_MODE_MASK  = 0b11

    ENDIF
