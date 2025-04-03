; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

; Driver for the reverse-engineered Alcatel SMS keyboard branded as "Clavier de saisie"

    INCLUDE "pio_h.asm"
    INCLUDE "drivers/keyboard_h.asm"
    INCLUDE "keyboard_h.asm"

    EXTERN keyboard_enqueue
    EXTERN keyboard_dequeue
    EXTERN keyboard_fifo_size

    DEFC SPECIAL_MAPPING = 0
    DEFC NORMAL_MAPPING  = 1

    SECTION KERNEL_DRV_TEXT

    ; Initialize the keyboard implementation. Here, we are going to use the user port since the keyboard should be
    ; plugged there.
    ; Parameters:
    ;   None
    ; Returns:
    ;   None
    ; Can alter anything
    PUBLIC keyboard_impl_init
keyboard_impl_init:
    ; Make the keyboard work asynchronously, via interrupts. Register interrupts for the user port.
    ; The user port will be used as input
    ld a, IO_PIO_INPUT
    out (IO_PIO_USER_CTRL), a
    ; Set the interrupt vector for the user port
    ld a, IO_USER_INTR_VECT
    out (IO_PIO_USER_CTRL), a
    ; Enable the interrupts globally for the user port
    ld a, IO_PIO_ENABLE_INT
    out (IO_PIO_USER_CTRL), a
    ; Clear the PIO register
    in a, (IO_PIO_USER_DATA)
    ; Register an interrupt handler to the PIO
    ld hl, alc_keyboard_isr
    jp pio_register_user_port_isr


alc_keyboard_isr:
    ; An interrupt was triggered (registers are free to use), push it into the FIFO.
    in a, (IO_PIO_USER_DATA)
    jp keyboard_enqueue


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
    ; Check if we have any available character in the keyboard FIFO
    call keyboard_dequeue
    ; If no character, return
    ret z
    ; When the key is pressed, bit 7 is set! Put the pressed/released index in B
    ld b, KB_EVT_PRESSED
    rlca
    jr c, @skip_release
    ; Released event
    ld b, KB_EVT_RELEASED
@skip_release:
    ld c, NORMAL_MAPPING
    ; Restore A value while set bit 7 to 0
    srl a
    ; Special keys are all strictly under 0x20
    cp 0x20
    jr c, @not_special
    ld c, SPECIAL_MAPPING
    ; No character below 0xC
    sub 0xc
    ld hl, special_lower_mapping
    add l
    ld l, a
    adc h
    sub l
    ld h, a
    ld a, (hl)
    ret
@not_special:
    ; Patch `+` and `:` since on the keyboard itself, they show `/ =` and `;` respectively
    cp '+'
    jr z, @plus_char
    cp ':'
    jr z, @colon_char
    cp '"'
    jr z, @quote_char
    ret
@plus_char:
    ld a, '/'
    ret
@colon_char:
    ld a, ';'
    ret
@quote_char:
    ld a, KB_KEY_QUOTE
    ret


    ; Check and convert the character pressed to upper if in base scan table
    ; Parameters:
    ;   B - Character received
    ;   C - Mapping index
    ;   HL - Address of the character in the table
    ; Returns:
    ;   B - Upper character
    PUBLIC keyboard_impl_upper
keyboard_impl_upper:
    ld a, c
    ; Default to special mapping
    ld bc, special_upper_mapping - special_lower_mapping
    cp SPECIAL_MAPPING
    jr z, @bc_ready
    ; Normal mapping, check letters
    ld a, b
    cp 'a'
    jr c, @not_letters
    sub 32
    ld b, a
    ret
@bc_ready:
    ; Switch to upper scan table
    add hl, bc
    ld b, (hl)
    ret
@not_letters:
    ; 0-9, , . ; ' - /= characters
    ret


special_lower_mapping:
    DEFM KB_UP_ARROW      ; Up key
    DEFM KB_DOWN_ARROW    ; Down key
    DEFM KB_LEFT_SHIFT    ; Shift
    DEFM KB_RIGHT_ALT     ; Alt
    DEFM KB_KEY_BACKSPACE ; Erase key
    DEFM 0x00             ; /Unused/
    DEFM '\n'             ; Ok key
    DEFM 0x00, 0x00, 0x00 ; /Unused/
    DEFM 0x00, 0x00, 0x00 ; /Unused/
    DEFM 0x00, 0x00       ; /Unused/
    DEFM KB_ESC           ; SMS
    DEFM '`'              ; WAP
    DEFM KB_CAPS_LOCK     ; Contact


special_upper_mapping:
    DEFM KB_LEFT_ARROW    ; Up key
    DEFM KB_RIGHT_ARROW   ; Down key
    DEFM KB_LEFT_SHIFT    ; Shift
    DEFM KB_RIGHT_CTRL    ; Alt
    DEFM KB_DELETE        ; Erase key
    DEFM 0x00             ; /Unused/
    DEFM '\n'             ; Ok key
    DEFM 0x00, 0x00, 0x00 ; /Unused/
    DEFM 0x00, 0x00, 0x00 ; /Unused/
    DEFM 0x00, 0x00       ; /Unused/
    DEFM KB_ESC           ; SMS
    DEFM '~'              ; WAP
    DEFM KB_CAPS_LOCK     ; Contact
