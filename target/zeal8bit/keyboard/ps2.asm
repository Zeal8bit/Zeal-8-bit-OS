; SPDX-FileCopyrightText: 2024 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

; Driver for the PS/2 keyboard protocol on Zeal 8-bit Computer motherboard

    INCLUDE "utils_h.asm"
    INCLUDE "keyboard_h.asm"

    EXTERN keyboard_enqueue
    EXTERN keyboard_dequeue
    EXTERN keyboard_fifo_size


    SECTION KERNEL_DRV_TEXT


    ; Initialize the keyboard implementation
    ; Parameters:
    ;   None
    ; Returns:
    ;   None
    ; Can alter anything
    PUBLIC keyboard_impl_init
keyboard_impl_init:
    ret


    ; Returns the next key pressed on the keyboard. If no key was pressed,
    ; it will wait for one if in blocking mode, else, it can return 0 if no
    ; key was pressed.
    ; Parameters:
        ;   A - 1 if in raw mode, 0 else
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
    ;       C - Scan table the character is in:
    ;            - BASE_SCAN_TABLE
    ;            - UPPER_SCAN_TABLE
    ;            - SPECIAL_TABLE
    ;            - EXT_SCAN_TABLE
    ;       HL - Address of the key pressed in the (base or special) scan
    ; Alters:
    ;       A, BC, (DE,) HL
    PUBLIC keyboard_impl_next_key
keyboard_impl_next_key:
    ; Check if we have any available character in the keyboard FIFO
    call keyboard_dequeue
    ; If no character, return
    ret z
    ; We just got a character, in A, check if we have to resume a previous
    ; step on hold (non-blocking mode)
    ld b, a
    ld hl, (kb_next_step)
    ld a, h
    or l
    jr z, _no_pending_step
    ; Clear the next step state
    xor a
    ld (kb_next_step), a
    ld (kb_next_step + 1), a
    ; Store the dequeued value back in A
    ld a, b
    jp (hl)
_no_pending_step:
    ; Store the dequeued value back in A
    ld a, b
    cp KB_RELEASE_SCAN      ; Test if A is a "release" command
    jp z, _release_char
    ; Character is not a "release command"
    ; Check if the character is a printable char
    cp KB_PRINTABLE_CNT - 1
    jp nc, _special_code ; jp nc <=> A >= KB_PRINTABLE_CNT - 1
_regular_scancode:
    ; Retrieve the character address in HL
    ld hl, base_scan
    ld c, BASE_SCAN_TABLE
_dereference_hl_ret:
    ADD_HL_A()
    ld a, (hl)
    ld b, KB_EVT_PRESSED
    ret
_special_code:
    ; Load in HL special scan codes
    ; Special character is still in A
    cp KB_EXTENDED_SCAN
    jp z, _extended_code
    add -KB_SPECIAL_START
    ld hl, special_scan
    ld c, SPECIAL_SCAN_TABLE
    jr _dereference_hl_ret
_release_char:
    ; Jump to this label if a RELEASE scan code was received without any
    ; special byte before (0xE0)
    ; Get the next byte from the FIFO and convert it if available
    call keyboard_impl_next_key
_release_char_resume:
    ld b, KB_EVT_RELEASED
    ; Return if the FIFO was NOT empty and A contains the byte returned
    or a
    ret nz
    ; We can reach here if the FIFO only contained the RELEASE scan code but not the
    ; character afterwards, in that case, keep the current state on hold and return 0
    call _keyboard_next_key_hold
    ; We come back here after scancode is available in A, we need to convert it.
    call _regular_scancode
    ; Replace the event and return
    ld b, KB_EVT_RELEASED
    ret
_extended_code:
    ; In case the received character is a released (special) character
    ; ignore it the same way it is done normally
    call keyboard_dequeue
    ; If there is no character in the FIFO (Z flag), save the current state and return
    call z, _keyboard_next_key_hold
    ; By default, set B as EVT_PRESSED
    ld b, KB_EVT_PRESSED
    ; Dequeued value in A already
    cp KB_RELEASE_SCAN
    jr nz, _extended_not_release
    ; We received release scan code, wait for the next character
    call keyboard_dequeue
    call z, _keyboard_next_key_hold
    ld b, KB_EVT_RELEASED
_extended_not_release:
    ld c, EXT_SCAN_TABLE
    ; These scan codes are particular:
    ; - Right Alt
    ; - Right Ctrl
    ; - Keypad /
    ; - Keypad Enter
    ; - Print Screen
    ; Treat them without any mapping
    cp KB_MAPPED_EXT_SCANS
    ; If result is negative, the received character is not mapped
    ; in the array used below
    jp c, _unmapped_ext_scans
    sub KB_MAPPED_EXT_SCANS
    ld hl, extended_scan
    ADD_HL_A()
    ld a, (hl)
    ret
_unmapped_ext_scans:
    ; BC has already been set previously
    cp KB_RIGHT_ALT_SCAN
    jr z, _right_alt_ret_rcved
    cp KB_RIGHT_CTRL_SCAN
    jr z, _right_ctrl_rcved
    cp KB_NUMPAD_DIV_SCAN
    jr z, _numpad_div_rcved
    cp KB_LEFT_SUPER_SCAN
    jr z, _left_super_rcved
    cp KB_NUMPAD_RET_SCAN
    jr z, _numpad_ret_rcved
    cp KB_PRT_SCREEN_SCAN
    jr z, _print_screen_rcved
    ld a, KB_UNKNOWN
    ret
_right_alt_ret_rcved:
    ld a, KB_RIGHT_ALT
    ret
_right_ctrl_rcved:
    ld a, KB_RIGHT_CTRL
    ret
_numpad_div_rcved:
    ld a, KB_NUMPAD_DIV
    ret
_numpad_ret_rcved:
    ld a, KB_NUMPAD_ENTER
    ret
_left_super_rcved:
    ld a, KB_LEFT_SPECIAL
    ret
_print_screen_rcved:
    ; Drop the next two characters (should be 0xE0 0x7C)
    call keyboard_dequeue
    call z, _keyboard_next_key_hold
    call keyboard_dequeue
    call z, _keyboard_next_key_hold
    ld a, KB_PRINT_SCREEN
    ld bc, (KB_EVT_PRESSED << 8) | EXT_SCAN_TABLE
    ret

    ; Hold the current step by saving the return address and return 0
_keyboard_next_key_hold:
    pop hl
    ld (kb_next_step), hl
    xor a
    ret


    ; Check and convert the character pressed to upper if in base scan table
    ; Parameters:
    ;   B - Character received
    ;   C - Scan table the character pressed was in
    ;   HL - Address of the character in base scan
    ; Returns:
    ;   B - Upper character
    PUBLIC keyboard_impl_upper
keyboard_impl_upper:
    ld a, c
    cp BASE_SCAN_TABLE
    ret nz
    ; Switch to upper scan table
    ld bc, upper_scan - base_scan
    add hl, bc
    ld b, (hl)
    ret


    IF CONFIG_TARGET_KEYBOARD_DVORAK
        INCLUDE "ps2_scan_dvorak.asm"
    ELSE
        INCLUDE "ps2_scan_qwerty.asm"
    ENDIF

special_scan:
    DEFB '\b', 0, 0, KB_NUMPAD_1, 0, KB_NUMPAD_4, KB_NUMPAD_7, 0, 0, 0, KB_NUMPAD_0
    DEFB KB_NUMPAD_DOT, KB_NUMPAD_2, KB_NUMPAD_5, KB_NUMPAD_6, KB_NUMPAD_8, KB_ESC
    DEFB KB_NUMPAD_LOCK, KB_F11, KB_NUMPAD_PLUS, KB_NUMPAD_3, KB_NUMPAD_MINUS, KB_NUMPAD_MUL
    DEFB KB_NUMPAD_9, KB_SCROLL_LOCK, 0, 0, 0, 0, KB_F7, 0, 0
extended_scan:
    DEFB KB_END, 0, KB_LEFT_ARROW, KB_HOME, 0, 0, 0, KB_INSERT, KB_DELETE, KB_DOWN_ARROW
    DEFB 0, KB_RIGHT_ARROW, KB_UP_ARROW, 0, 0, 0, 0, KB_PG_DOWN, 0, 0, KB_PG_UP




    PUBLIC keyboard_ps2_int_handler
keyboard_ps2_int_handler:
    ; Enqueue the PS/2 scan code we just received
    in a, (KB_IO_ADDRESS)
    jp keyboard_enqueue




    SECTION DRIVER_BSS

    ; State that will be updated according to the keys received in non-blocking mode
kb_next_step: DEFS 2