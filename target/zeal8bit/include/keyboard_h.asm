; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    IFNDEF KEYBOARD_H
    DEFINE KEYBOARD_H

    ; Macros for keyboard
    DEFC KB_IO_ADDRESS = 0xE8

    DEFC KEYBOARD_SHIFT_FLAGS = (1 << KB_RSHIFT_BIT) | (1 << KB_LSHIFT_BIT)

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
    DEFC KB_IGNORE_MODIF  = 0x7
    DEFC KB_RCTRL_BIT 	  = 0x6
    DEFC KB_LCTRL_BIT 	  = 0x5
    DEFC KB_RALT_BIT 	  = 0x4
    DEFC KB_LALT_BIT 	  = 0x3
    DEFC KB_RSHIFT_BIT 	  = 0x2
    DEFC KB_LSHIFT_BIT 	  = 0x1
    DEFC KB_CAPSL_BIT 	  = 0x0

    ; Keyboard keycode
    DEFC KB_NUMPAD_0	  = 0x80
    DEFC KB_NUMPAD_1	  = 0x81
    DEFC KB_NUMPAD_2	  = 0x82
    DEFC KB_NUMPAD_3	  = 0x83
    DEFC KB_NUMPAD_4	  = 0x84
    DEFC KB_NUMPAD_5	  = 0x85
    DEFC KB_NUMPAD_6	  = 0x86
    DEFC KB_NUMPAD_7	  = 0x87
    DEFC KB_NUMPAD_8	  = 0x88
    DEFC KB_NUMPAD_9	  = 0x89
    DEFC KB_NUMPAD_DOT	  = 0x8a
    DEFC KB_NUMPAD_ENTER  = 0x8b
    DEFC KB_NUMPAD_PLUS	  = 0x8c
    DEFC KB_NUMPAD_MINUS  = 0x8d
    DEFC KB_NUMPAD_MUL    = 0x8e
    DEFC KB_NUMPAD_DIV    = 0x8f
    DEFC KB_NUMPAD_LOCK   = 0x90
    DEFC KB_SCROLL_LOCK	  = 0x91
    DEFC KB_CAPS_LOCK	  = 0x92
    DEFC KB_LEFT_SHIFT	  = 0x93
    DEFC KB_LEFT_ALT	  = 0x94
    DEFC KB_LEFT_CTRL	  = 0x95
    DEFC KB_RIGHT_SHIFT	  = 0x96
    DEFC KB_RIGHT_ALT	  = 0x97
    DEFC KB_RIGHT_CTRL	  = 0x98
    DEFC KB_HOME          = 0x99
    DEFC KB_END           = 0x9a
    DEFC KB_INSERT        = 0x9b
    DEFC KB_DELETE        = 0x9c
    DEFC KB_PG_DOWN       = 0x9d
    DEFc KB_PG_UP         = 0x9e
    DEFC KB_PRINT_SCREEN  = 0x9f
    DEFC KB_UP_ARROW      = 0xa0
    DEFC KB_DOWN_ARROW    = 0xa1
    DEFC KB_LEFT_ARROW    = 0xa2
    DEFC KB_RIGHT_ARROW   = 0xa3
    DEFC KB_LEFT_SPECIAL  = 0xa4
    DEFC KB_ESC		  	  = 0xf0
    DEFC KB_F1		  	  = 0xf1
    DEFC KB_F2		  	  = 0xf2
    DEFC KB_F3		  	  = 0xf3
    DEFC KB_F4		  	  = 0xf4
    DEFC KB_F5		  	  = 0xf5
    DEFC KB_F6		  	  = 0xf6
    DEFC KB_F7		  	  = 0xf7
    DEFC KB_F8		  	  = 0xf8
    DEFC KB_F9		  	  = 0xf9
    DEFC KB_F10		  	  = 0xfa
    DEFC KB_F11		  	  = 0xfb
    DEFC KB_F12		  	  = 0xfc
    DEFC KB_UNKNOWN		  = 0xff

    ENDIF
