
; SPDX-FileCopyrightText: 2024 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .equiv ZOS_KEYBOARD_H, 1

    ; This file represents the keyboard interface for a key input driver.

    ; kb_cmd_t: This group represents the IOCTL commands an input/keyboard driver should implement
    ; Set the current input mode, check the attributes in the group below.
    ; Parameters:
    ;   E - New mode
    .equ KB_CMD_SET_MODE, 0
    ; Number of commands above
    .equ KB_CMD_COUNT, 1


    ; kb_mode_t: Modes supported by input/keyboard driver
    ; In raw mode, all the characters that are pressed or released are sent to the user
    ; program when a read occurs.
    ; This means that no treatment is performed by the driver whatsoever. For example,
    ; if (Left) Shift and A are pressed, the bytes sent to the user program will be:
    ;    0x93          0x61
    ; Left shift   Ascii lower A
    ; The non-special characters must be sent in lowercase mode.
    .equ KB_MODE_RAW, 0
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
    .equ KB_MODE_COOKED, 1
    ; HALFCOOKED mode is similar to COOKED mode, the difference is, when an
    ; unsupported key is pressed, instead of being ignored, it is filled in
    ; the buffer and a special error code is returned: ERR_SPECIAL_STATE
    ; The "release key" events shall still be ignored and not transmitted to
    ; the user program.
    .equ KB_MODE_HALFCOOKED, 2
    ; Number of modes above
    .equ KB_MODE_COUNT, 3


    ; kb_block_t: Blocking/non-blocking modes, can be ORed with the mode above
    ; In blocking mode, the `read` syscall will not return until a newline character ('\n')
    ; is encountered.
    .equ KB_READ_BLOCK, 0 << 2
    ; In non-blocking mode, the syscall `read` can return 0 if there is no pending keys that were
    ; typed by the user. Please note that the driver must NOT return KB_RELEASED without a key following it.
    ; In other words, if the buffer[i] has been filled with a KB_RELEASED, buffer[i+1] must be valid
    ; and contain the key that was released.
    .equ KB_READ_NON_BLOCK, 1 << 2


    ; The following codes represent the keys of a 104-key keyboard that can be detected by
    ; the keyboard driver.
    ; When the input mode is set to RAW, the following keys can be sent to the
    ; user program to mark which keys were pressed (or released).
    .equ KB_KEY_A, 'a'
    .equ KB_KEY_B, 'b'
    .equ KB_KEY_C, 'c'
    .equ KB_KEY_D, 'd'
    .equ KB_KEY_E, 'e'
    .equ KB_KEY_F, 'f'
    .equ KB_KEY_G, 'g'
    .equ KB_KEY_H, 'h'
    .equ KB_KEY_I, 'i'
    .equ KB_KEY_J, 'j'
    .equ KB_KEY_K, 'k'
    .equ KB_KEY_L, 'l'
    .equ KB_KEY_M, 'm'
    .equ KB_KEY_N, 'n'
    .equ KB_KEY_O, 'o'
    .equ KB_KEY_P, 'p'
    .equ KB_KEY_Q, 'q'
    .equ KB_KEY_R, 'r'
    .equ KB_KEY_S, 's'
    .equ KB_KEY_T, 't'
    .equ KB_KEY_U, 'u'
    .equ KB_KEY_V, 'v'
    .equ KB_KEY_W, 'w'
    .equ KB_KEY_X, 'x'
    .equ KB_KEY_Y, 'y'
    .equ KB_KEY_Z, 'z'
    .equ KB_KEY_0, '0'
    .equ KB_KEY_1, '1'
    .equ KB_KEY_2, '2'
    .equ KB_KEY_3, '3'
    .equ KB_KEY_4, '4'
    .equ KB_KEY_5, '5'
    .equ KB_KEY_6, '6'
    .equ KB_KEY_7, '7'
    .equ KB_KEY_8, '8'
    .equ KB_KEY_9, '9'
    .equ KB_KEY_BACKQUOTE,     '`'
    .equ KB_KEY_MINUS,         '-'
    .equ KB_KEY_EQUAL,         '='
    .equ KB_KEY_BACKSPACE,     0x08 ; \b
    .equ KB_KEY_SPACE,         ' '
    .equ KB_KEY_ENTER,         0x0a ; \n
    .equ KB_KEY_TAB,           0x09 ; \t
    .equ KB_KEY_COMMA,         ','
    .equ KB_KEY_PERIOD,        '.'
    .equ KB_KEY_SLASH,         '/'
    .equ KB_KEY_SEMICOLON,     ';'
    .equ KB_KEY_QUOTE,         0x27
    .equ KB_KEY_LEFT_BRACKET,  '['
    .equ KB_KEY_RIGHT_BRACKET, ']'
    .equ KB_KEY_BACKSLASH,     0x5c

    ; When the input mode is set to RAW or HALFCOOKED, the following keys can be sent to the
    ; user program to mark which special keys were pressed (or released).
    .equ KB_NUMPAD_0,       0x80
    .equ KB_NUMPAD_1,       0x81
    .equ KB_NUMPAD_2,       0x82
    .equ KB_NUMPAD_3,       0x83
    .equ KB_NUMPAD_4,       0x84
    .equ KB_NUMPAD_5,       0x85
    .equ KB_NUMPAD_6,       0x86
    .equ KB_NUMPAD_7,       0x87
    .equ KB_NUMPAD_8,       0x88
    .equ KB_NUMPAD_9,       0x89
    .equ KB_NUMPAD_DOT,     0x8a
    .equ KB_NUMPAD_ENTER,   0x8b
    .equ KB_NUMPAD_PLUS,    0x8c
    .equ KB_NUMPAD_MINUS,   0x8d
    .equ KB_NUMPAD_MUL,     0x8e
    .equ KB_NUMPAD_DIV,     0x8f
    .equ KB_NUMPAD_LOCK,    0x90
    .equ KB_SCROLL_LOCK,    0x91
    .equ KB_CAPS_LOCK,      0x92
    .equ KB_LEFT_SHIFT,     0x93
    .equ KB_LEFT_ALT,       0x94
    .equ KB_LEFT_CTRL,      0x95
    .equ KB_RIGHT_SHIFT,    0x96
    .equ KB_RIGHT_ALT,      0x97
    .equ KB_RIGHT_CTRL,     0x98
    .equ KB_HOME,           0x99
    .equ KB_END,            0x9a
    .equ KB_INSERT,         0x9b
    .equ KB_DELETE,         0x9c
    .equ KB_PG_DOWN,        0x9d
    .equ KB_PG_UP,          0x9e
    .equ KB_PRINT_SCREEN,   0x9f
    .equ KB_UP_ARROW,       0xa0
    .equ KB_DOWN_ARROW,     0xa1
    .equ KB_LEFT_ARROW,     0xa2
    .equ KB_RIGHT_ARROW,    0xa3
    .equ KB_LEFT_SPECIAL,   0xa4

    .equ KB_ESC,            0xf0
    .equ KB_F1,             0xf1
    .equ KB_F2,             0xf2
    .equ KB_F3,             0xf3
    .equ KB_F4,             0xf4
    .equ KB_F5,             0xf5
    .equ KB_F6,             0xf6
    .equ KB_F7,             0xf7
    .equ KB_F8,             0xf8
    .equ KB_F9,             0xf9
    .equ KB_F10,            0xfa
    .equ KB_F11,            0xfb
    .equ KB_F12,            0xfc

    ; When a released event is triggered, this value shall precede the key concerned.
    ; As such, in RAW mode, each key press should at some point generate a release
    ; sequence. For example:
    ;   0x61 [...] 0xFE 0x61
    ;    A   [...] A released
    .equ KB_RELEASED,       0xfe
    .equ KB_UNKNOWN,        0xff
