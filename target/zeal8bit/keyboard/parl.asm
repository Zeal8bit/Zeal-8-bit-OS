; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

; Driver for the parallel keyboard on Zeal 8-bit Computer motherboard

    INCLUDE "utils_h.asm"
    INCLUDE "utils_h.asm"
    INCLUDE "drivers/keyboard_h.asm"

    DEFC KB_RST_ADDRESS     = 0xE0
    DEFC KB_CUR_ADDRESS     = 0xE2
    DEFC KB_NXT_ADDRESS     = 0xE3
    DEFC KB_EVT_PRESSED     = 0
    DEFC KB_EVT_RELEASED    = 1

    EXTERN keyboard_enqueue
    EXTERN keyboard_dequeue
    EXTERN keyboard_fifo_size
    EXTERN zos_time_msleep

    SECTION KERNEL_DRV_TEXT

    ; Initialize the keyboard implementation
    ; Parameters:
    ;   None
    ; Returns:
    ;   None
    ; Can alter anything
    PUBLIC keyboard_impl_init
keyboard_impl_init:
    ; Turn off LEDs
    xor a
    out (KB_CUR_ADDRESS), a
    ret


    ; Returns the next key pressed on the keyboard. If no key was pressed,
    ; it will wait for one if in blocking mode, else, it can return 0 if no
    ; key was pressed.
    ; Parameters:
    ;       A - 1 if in raw mode, 0 else
    ; Returns:
    ;       A - Pressed Key. If A is less than 128 (highest bit is 0),
    ;           it contains an ASCII character, else, it shall be compared
    ;           to the other characters code.
    ;           0 means that no character was available.
    ;       B - Event:
    ;            - KB_EVT_PRESSED
    ;            - KB_EVT_RELEASED
    ;
    ;       C and HL are opaque values passed to `keyboard_switch_to_upper`
    ; Alters:
    ;       A, BC, (DE,) HL
    PUBLIC keyboard_impl_next_key
keyboard_impl_next_key:
    ; If in RAW mode, sleep for a while to prevent bouncing
    ; ld de, 1
    ; or a
    ; call nz, zos_time_msleep

    ld hl, kb_previous_state
    ld b, 10
    ; Poll the keyboard for any pressed key. Reset the column counter while
    ; getting the first line
    in a, (KB_RST_ADDRESS)
    jp _impl_skip_first
keyboard_impl_next_key_loop:
    in a, (KB_NXT_ADDRESS)
_impl_skip_first:
    ; Get the former value and store the new one in the array
    cp (hl)
    call nz, _keyboard_impl_state_change
    inc hl
    djnz keyboard_impl_next_key_loop
    ; Check if we have any available character in the keyboard FIFO
    call keyboard_dequeue
    ; If no character, return
    ret z
    ; Put the pressed/released index in B
    ld b, a
    ; A contains the index of the key to return, keep it in C and calculate its address in HL
    call keyboard_dequeue
    ; Make the assumption that the FIFO is not empty. A contains the index of the key
    ; to return.
    ld hl, key_mapping
    add l
    ld l, a
    adc h
    sub l
    ld h, a
    ld a, (hl)
    ret


    ; Routine called when a state changed in the keyboard
    ; Parameters:
    ;   A - New value
    ;   [HL] - Former value
    ;   B - Remaining columns
    ; Returns:
    ;   None
    ; Alters:
    ;   C, DE
    ; Must not alter A, HL and B
_keyboard_impl_state_change:
    ld c, a
    push bc
    push hl
    ; C is now saved on the stack
    ; Calculate the index of the current column
    ld a, 10
    ; A = (10 - B) * 8
    sub b
    rlca
    rlca
    rlca
    ; Store the index in B
    ld b, a
    ; Get the former value in both A and E, and store the new value in the array
    ld a, (hl)
    ld e, a
    ld (hl), c
    ; New value is in C, must not be altered
    xor c
    ; Bit 7 is always 0, only check the remaining 7 bits
    rrca
    call c, _keyboard_impl_push
    rr e    ; Shift the former value to let _keyboard_impl_push check the lowest bit
    inc b
    rrca
    call c, _keyboard_impl_push
    rr e
    inc b
    rrca
    call c, _keyboard_impl_push
    rr e
    inc b
    rrca
    call c, _keyboard_impl_push
    rr e
    inc b
    rrca
    call c, _keyboard_impl_push
    rr e
    inc b
    rrca
    call c, _keyboard_impl_push
    rr e
    inc b
    rrca
    call c, _keyboard_impl_push
    pop hl
    pop bc
    ; Restore A original value
    ld a, c
    ret

    ; Push the value pointed by HL into the FIFO
    ; Parameters:
    ;   B - Index of the key pressed (0-79)
    ;   E - Former value
    ; Alters:
    ;   Must not alter A, BC
_keyboard_impl_push:
    ld d, a
    ; Check the lowest bit of the former value, if it is set to 1,
    ; the key was released, else it was pressed. Store that bit in A.
    xor a
    ; Get the lowest bit but do not modify E
    rrc e
    adc a
    rlc e
    call keyboard_enqueue
    ld a, b ; Enqueuing value 0 is valid
    call keyboard_enqueue
    ld a, d
    ret




    ; Check and convert the character pressed to upper if in base scan table
    ; Parameters:
    ;   B - Character received
    ;   C - Index of the character pressed in the `key_mapping` table
    ;   HL - Address of the character in the table
    ; Returns:
    ;   B - Upper character
    PUBLIC keyboard_impl_upper
keyboard_impl_upper:
    ; Shift the table address by key_mapping_size
    ld bc, key_mapping_end - key_mapping
    add hl, bc
    ld b, (hl)
    ret


key_mapping:
    ; 0xFF represents the function key
    DB KB_KEY_BACKQUOTE, KB_KEY_2,        KB_KEY_4,     KB_KEY_6,     KB_KEY_8,         KB_KEY_MINUS,         KB_KEY_BACKSPACE, 0
    DB KB_KEY_1,         KB_KEY_3,        KB_KEY_5,     KB_KEY_7,     KB_KEY_9,         KB_KEY_EQUAL,         KB_DELETE,        0
    DB KB_KEY_TAB,       KB_KEY_W,        KB_KEY_R,     KB_KEY_Y,     KB_KEY_0,         KB_KEY_LEFT_BRACKET,  KB_KEY_ENTER,     0
    DB KB_KEY_Q,         KB_KEY_E,        KB_KEY_T,     KB_KEY_U,     KB_KEY_O,         KB_KEY_RIGHT_BRACKET, KB_INSERT,        0
    DB KB_CAPS_LOCK,     KB_KEY_S,        KB_KEY_F,     KB_KEY_I,     KB_KEY_P,         KB_KEY_QUOTE,         KB_PG_UP,         0
    DB KB_KEY_A,         KB_KEY_D,        KB_KEY_G,     KB_KEY_H,     KB_KEY_L,         KB_KEY_BACKSLASH,     KB_PG_DOWN,       0
    DB KB_LEFT_SHIFT,    KB_KEY_X,        KB_KEY_V,     KB_KEY_J,     KB_KEY_SEMICOLON, KB_RIGHT_SHIFT,       KB_DOWN_ARROW,    0
    DB KB_KEY_Z,         KB_KEY_C,        KB_KEY_B,     KB_KEY_K,     KB_KEY_PERIOD,    KB_UP_ARROW,          KB_RIGHT_ARROW,   0
    DB KB_LEFT_CTRL,     KB_LEFT_SPECIAL, KB_KEY_N,     KB_KEY_M,     KB_KEY_SLASH,     KB_RIGHT_CTRL,        0,                0
    DB 0xFF,             KB_LEFT_ALT,     KB_KEY_SPACE, KB_KEY_COMMA, KB_RIGHT_ALT,     KB_LEFT_ARROW,        0,                0
key_mapping_end:

    ; Same as above but applies when the SHIFT or CAPS lock is set
upper_key_mapping:
    DB '~',              '@',             '$',          '^',          '*',              '_',                  KB_KEY_BACKSPACE, 0
    DB '!',              '#',             '%',          '&',          '(',              '+',                  KB_DELETE,        0
    DB KB_KEY_TAB,       'W',             'R',          'Y',          ')',              '{',                  KB_KEY_ENTER,     0
    DB 'Q',              'E',             'T',          'U',          'O',              '}',                  KB_INSERT,        0
    DB KB_CAPS_LOCK,     'S',             'F',          'I',          'P',              '"',                  KB_PG_UP,         0
    DB 'A',              'D',             'G',          'H',          'L',              '|',                  KB_PG_DOWN,       0
    DB KB_LEFT_SHIFT,    'X',             'V',          'J',          ':',              KB_RIGHT_SHIFT,       KB_DOWN_ARROW,    0
    DB 'Z',              'C',             'B',          'K',          '>',              KB_UP_ARROW,          KB_RIGHT_ARROW,   0
    DB KB_LEFT_CTRL,     KB_LEFT_SPECIAL, 'N',          'M',          '?',              KB_RIGHT_CTRL,        0,                0
    DB 0xFF,             KB_LEFT_ALT,     KB_KEY_SPACE, '<',          KB_RIGHT_ALT,     KB_LEFT_ARROW,        0,                0


    SECTION DRIVER_BSS

    ; State that will be updated according to the keys received in non-blocking mode
kb_previous_state: DEFS 10