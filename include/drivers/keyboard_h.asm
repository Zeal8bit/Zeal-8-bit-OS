
; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    IFNDEF DRIVERS_KEYBOARD_H
    DEFINE DRIVERS_KEYBOARD_H

    ; This file represents the keyboard interface for a key input driver.

    ; kb_cmd_t: This group represents the IOCTL commands an input/keyboard driver should implement
    DEFGROUP {
        ; Set the current input mode, check the attributes in the group below.
        ; Parameters:
        ;   E - New mode
        KB_CMD_SET_MODE = 0,

        ; Number of commands above
        KB_CMD_COUNT
    }

    ; kb_mode_t: Modes supported by input/keyboard driver
    DEFGROUP {
        ; In raw mode, all the characters that are pressed or released are sent to the user
        ; program when a read occurs.
        ; This means that no treatment is performed by the driver whatsoever. For example,
        ; if (Left) Shift and A are pressed, the bytes sent to the user program will be:
        ;    0x93          0x61
        ; Left shift   Ascii lower A
        ; The non-special characters must be sent in lowercase mode.
        KB_MODE_RAW = 0,

        ; In COOKED mode, the entry is buffered. So when a key is pressed, it is
        ; first processed before being stored in a buffer and sent to the user
        ; program (on "read").
        ; The buffer is flushed when it is full or when Enter ('\n') is pressed.
        ; The keys that will be treated by the driver are:
        ;   - Non-special characters:
        ;       which includes all printable characters: letters, numbers, punctuation, etc.
        ;   - Special characters that have a well defined behavior:
        ;       which includes caps lock, (left/right) shifts, left arrow,
        ;       right arrow, delete key, tabulation, enter.
        ; The remaining special characters are ignored. Release key events are
        ; also ignored.
        KB_MODE_COOKED,

        ; HALFCOOKED mode is similar to COOKED mode, the difference is, when an
        ; unsupported key is pressed, instead of being ignored, it is filled in
        ; the buffer and a special error code is returned: ERR_SPECIAL_STATE
        ; The "release key" events shall still be ignored and not transmitted to
        ; the user program.
        KB_MODE_HALFCOOKED,

        ; Number of modes above
        KB_MODE_COUNT,
    }


    ; The following codes represent the special keys of a 104-key keyboard.
    ; When the input mode is not set to COOKED, the following keys can be sent to the
    ; user program to mark which special keys were pressed (or released)
    DEFC KB_NUMPAD_0      = 0x80
    DEFC KB_NUMPAD_1      = 0x81
    DEFC KB_NUMPAD_2      = 0x82
    DEFC KB_NUMPAD_3      = 0x83
    DEFC KB_NUMPAD_4      = 0x84
    DEFC KB_NUMPAD_5      = 0x85
    DEFC KB_NUMPAD_6      = 0x86
    DEFC KB_NUMPAD_7      = 0x87
    DEFC KB_NUMPAD_8      = 0x88
    DEFC KB_NUMPAD_9      = 0x89
    DEFC KB_NUMPAD_DOT    = 0x8a
    DEFC KB_NUMPAD_ENTER  = 0x8b
    DEFC KB_NUMPAD_PLUS   = 0x8c
    DEFC KB_NUMPAD_MINUS  = 0x8d
    DEFC KB_NUMPAD_MUL    = 0x8e
    DEFC KB_NUMPAD_DIV    = 0x8f
    DEFC KB_NUMPAD_LOCK   = 0x90
    DEFC KB_SCROLL_LOCK   = 0x91
    DEFC KB_CAPS_LOCK     = 0x92
    DEFC KB_LEFT_SHIFT    = 0x93
    DEFC KB_LEFT_ALT      = 0x94
    DEFC KB_LEFT_CTRL     = 0x95
    DEFC KB_RIGHT_SHIFT   = 0x96
    DEFC KB_RIGHT_ALT     = 0x97
    DEFC KB_RIGHT_CTRL    = 0x98
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

    DEFC KB_ESC           = 0xf0
    DEFC KB_F1            = 0xf1
    DEFC KB_F2            = 0xf2
    DEFC KB_F3            = 0xf3
    DEFC KB_F4            = 0xf4
    DEFC KB_F5            = 0xf5
    DEFC KB_F6            = 0xf6
    DEFC KB_F7            = 0xf7
    DEFC KB_F8            = 0xf8
    DEFC KB_F9            = 0xf9
    DEFC KB_F10           = 0xfa
    DEFC KB_F11           = 0xfb
    DEFC KB_F12           = 0xfc

    ; When a released event is triggered, this value shall precede the key concerned.
    ; As such, in RAW mode, each key press should at some point generate a release
    ; sequence. For example:
    ;   0x61 [...] 0xFE 0x61
    ;    A   [...] A released
    DEFC KB_RELEASED      = 0xfe
    DEFC KB_UNKNOWN       = 0xff

    ENDIF ; DRIVERS_KEYBOARD_H
