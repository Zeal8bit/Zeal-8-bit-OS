; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "errors_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "interrupt_h.asm"
        INCLUDE "keyboard_h.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "stdout_h.asm"

        DEFC KEYBOARD_FIFO_SIZE = 16
        DEFC KEYBOARD_INTERNAL_BUFFER_SIZE = 80

        EXTERN zos_sys_reserve_page_1
        EXTERN zos_sys_restore_pages
        EXTERN zos_vfs_set_stdin

        SECTION KERNEL_DRV_TEXT
        ; Initialize the keyboard driver. This is called only once, at boot up.
keyboard_init:
        ; Initialize the software FIFO
        ld hl, kb_fifo
        ld (kb_fifo_wr), hl
        ld (kb_fifo_rd), hl
        ; Register the keyboard as the default stdin
        ld hl, this_struct
        call zos_vfs_set_stdin
keyboard_deinit:
keyboard_open:
        ld a, ERR_SUCCESS
        ret


keyboard_write:
keyboard_seek:
        ld a, ERR_NOT_SUPPORTED
        ret


        ; Perform an I/O requested by the user application.
        ; Parameters:
        ;       B - Dev number the I/O request is performed on.
        ;       C - Command number. Driver-dependent.
        ;       DE - 16-bit parameter, also driver-dependent.
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ;       DE - Driver dependent, NOT PRESERVED
        ; Alters:
        ;       A, BC, DE, HL
keyboard_ioctl:
        ld a, c
        cp KB_CMD_SET_MODE
        jr nz, _keyboard_invalid_parameter
        ; Check if the given mode is a valid mode
        ld a, e
        cp KB_MODE_COUNT
        jr nc, _keyboard_invalid_parameter
        ; Update the flags
        ld a, (kb_flags)
        and ~KB_FLAG_MODE_MASK
        or e
        ld (kb_flags), a
        ; Return success
        xor a
        ret
_keyboard_invalid_parameter:
        ld a, ERR_INVALID_PARAMETER
        ret


        ; Read characters from the keyboard
        ; Parameters:
        ;       DE - Destination buffer.
        ;       BC - Size to read in bytes. Guaranteed to be equal to or smaller than 16KB.
        ;       A  - Should be DRIVER_OP_NO_OFFSET in our case (as not registered as a disk)
        ; Returns:
        ;       A  - ERR_SUCCESS if success, error code else
        ;       BC - Number of bytes read.
        ; Alters:
        ;       This function can alter any register.
keyboard_read:
        ; If the parameter is 0, return
        ld a, b
        or c
        ret z
        ld a, (kb_flags)
        and KB_FLAG_MODE_MASK
        cp KB_MODE_RAW
        jp z, keyboard_read_raw
        ; Read into the internal buffer first
        push de
        push bc
        call stdout_op_start
        call keyboard_read_cooked
        call stdout_op_end
        ; Copy the internal buffer to the user buffer
        ; BC contains the size of the filled internal buffer.
        ; DE contains the address of the internal buffer to copy from.
        ; We have to copy the minimum between filled buffer and
        ; user buffer length
        pop hl
        xor a
        sbc hl, bc
        jr c, _keyboard_read_bc_bigger
        ; HL was bigger than (or equal to) BC
        ; We will copy BC bytes to the user's buffer.
_keyboard_read_copy_to_user:
        ex de, hl       ; internal buffer becomes the source
        pop de
        ; BC is set to the minimum already, push it to return it afterwards
        push bc
        ldir
        pop bc
        ret
_keyboard_read_bc_bigger:
        ; HL was smaller, we need to retrieve it.
        add hl, bc
        ld b, h
        ld c, l
        jp _keyboard_read_copy_to_user


        ; Close the keyboard instance, in our case, we will clean the FIFO
keyboard_close:
        xor a
        ret

        ;======================================================================;
        ;================= P R I V A T E   R O U T I N E S ====================;
        ;======================================================================;


        ; Read the bytes from the keyboard in the internal buffer in cooked mode.
        ; We can only return once the new line character has been pressed.
        ; Moreover, when this happens, the buffer will be printed to the screen.
        ; Parameters:
        ;       None
        ; Returns:
        ;       DE - Address of the buffer where we filled the bytes
        ;       BC - Number of bytes filled in DE
        ; Alters:
        ;       A, BC, DE, HL
keyboard_read_cooked:
        ; If the buffer is full, it will still not be sent to the user
        ; because it would still be possible to go back and remove some
        ; characters
_keyboard_read_ignore:
_keyboard_read_ignore_no_update:
        call keyboard_next_pressed_key
        ; Optimize KB_EVT_RELEASED == 1 case
        ASSERT(KB_EVT_RELEASED == 1)
        dec b
        jp z, _keyboard_read_released_key
        ; The graphic driver should now take care of the cursor
        ; Check that it is a printable character: from 0x20 to 0x7E
        bit 7, a
        jp nz, _keyboard_extended_char
        cp 0x20
        jp c, _keyboard_ctrl_char
        ; Printable character, save it and print it in B!
        ld b, a
        ; If the character received was in the base scan, we may need to convert it to
        ; an upper scan character if shift or caps lock is activated.
        ld a, (kb_flags)
        and 1 << KB_FLAG_SHIFT_BIT
        call nz, keyboard_switch_to_upper
        ; Check that the size has not reached the maximum
        ld a, (kb_buffer_size)
        cp KEYBOARD_INTERNAL_BUFFER_SIZE - 1    ; Keep space for the last \n
        jr z, _keyboard_read_ignore     ; Ignore this character as the line is full already
        ; Line not full, append the character to the buffer
        ld c, a                         ; c contains the size of the buffer
        ld a, (kb_buffer_cursor)
        ld e, a                         ; e contains the cursor in the buffer
        ; HL = kb_internal_buffer + command_cursor
        ld hl, kb_internal_buffer
        ADD_HL_A()
        ld a, e
        ; If the cursor is not at the end (e.g. not equal to the size),
        ; we have to shift the whole command to the right
        sub c
        ; A needs to be 0 if we jump directly to not_shift label
        jp z, _keyboard_not_shift
        add c
        push bc
        ; We have to copy from the end to the cursor
        ; So let's make DE (destination) point to the end of the buffer
        ; DE = kb_internal_buffer (HL) + size (C)
        ld hl, kb_internal_buffer
        ld b, 0
        add hl, bc
        ld d, h
        ld e, l
        ; HL points to the character right before DE
        dec hl
        ; We have to move (size - cursor) bytes
        neg
        add c
        ; Put it into BC for ldrr instruction. (B is already 0)
        ld c, a
        ; Both HL and DE will be decremented
        lddr
        ; We will have to tell the video driver to update the line
        ; Characters moved count in a.
        ld c, a
        inc c
        ; Pop character to print in A, but keep it on the stack
        pop af
        push af
        ; Save the character in the buffer!
        ld (de), a
        ; Print the rest of the buffer on the screen.
        call stdout_print_buffer
        pop af
        call stdout_print_char
        jp _keyboard_increment_size_and_cursor
_keyboard_not_shift:
        ; Save the character in the buffer!
        ld (hl), b
        ; Characters moved count in a
        ld c, a
        inc c
        ; Print the characters (b) on the screen.
        ; It's not mandatory to put the right BC and DE
        ; as these are only used in case the characters to "print"
        ; is escape character (0x1b)
        ; But we better be safe than sorry, so let's keep it for the moment
        ld a, b
        ld b, 0 ; print_buffer takes 16-bit size
        ex de, hl
        call stdout_print_char
_keyboard_increment_size_and_cursor:
        ; Now increment the size of the buffer
        ld hl, kb_buffer_size
        inc (hl)
        inc hl ; kb_buffer_cursor
        inc (hl)
        jp _keyboard_read_ignore
_keyboard_ctrl_char:
        cp '\b'
        jp z, _keyboard_ctrl_backspace
        cp '\n'
        jp z, _keyboard_ctrl_newline
        jp _keyboard_read_ignore
_keyboard_ctrl_backspace:
        ; The cursor shall not be at the beginning of the line
        ld a, (kb_buffer_cursor)
        or a
        jp z, _keyboard_read_ignore
        ; BC contains kb_buffer_size - cursor (A)
        ; HL contains &command_buffer + cursor
        ; DE contains HL - 1
        ld hl, kb_internal_buffer
        ld c, a ; Save cursor in C
        ADD_HL_A()
        ld d, h
        ld e, l
        dec de
        push de ; We will use it to update the video
        ld a, (kb_buffer_size)
        ; The total length to copy shall be incremented to avoid having
        ; BC = 0
        inc a
        sub c
        ld b, 0
        ld c, a
        push bc
        ldir
        ; As we incremented the length, HL points to the character after
        ; the last (duplicated) one. Remove this duplicate thanks to DE.
        ; Add a space to clear the duplicate character on screen, but inside
        ; the buffer, store a 0
        ld a, ' '
        dec de
        push de
        ld (de), a      ; [de] = space
        ; Decrement buffer size and cursor
        ld hl, kb_buffer_size
        dec (hl)
        inc hl ; kb_buffer_cursor
        dec (hl)
        ; Move the video cursor left
        ld a, '\b'
        call stdout_print_char
        pop hl ; End last char of buffer to replace with 0
        pop bc
        pop de
        push hl
        call stdout_print_buffer
        pop hl
        ld (hl), 0
        jp _keyboard_read_ignore
_keyboard_ctrl_newline:
        ; Add new line character to the end of the buffer
        ld hl, kb_internal_buffer
        ld a, (kb_buffer_size)
        ld b, 0
        ld c, a
        add hl, bc
        ld (hl), '\n'
        ; Reset the size and the cursor for the next iteration
        ld hl, kb_buffer_size
        ld (hl), b      ; B is zero here
        inc hl ; kb_buffer_cursor
        ld (hl), b
        ; BC is the size, increment because of '\n'
        inc c
        push bc
        ld a, '\n'
        call stdout_print_char
        pop bc
        ; Prepare the return values:
        ; DE - Address of the buffer
        ; BC - Size of the buffer, including '\n'
        ld de, kb_internal_buffer
        ret
_keyboard_extended_char:
        cp KB_CAPS_LOCK
        jr z, _keyboard_extended_toggle_shift
        cp KB_LEFT_SHIFT
        jr z, _keyboard_extended_toggle_shift
        cp KB_RIGHT_SHIFT
        jr z, _keyboard_extended_toggle_shift

        ld hl, kb_buffer_cursor
        cp KB_LEFT_ARROW
        jr z, _keyboard_extended_left_arrow
        cp KB_RIGHT_ARROW
        jr z, _keyboard_extended_right_arrow
        cp KB_UP_ARROW
        jr z, _keyboard_extended_up_arrow
        cp KB_DOWN_ARROW
        jr z, _keyboard_extended_down_arrow
        jp _keyboard_read_ignore
_keyboard_read_released_key:
        ; Check if the key released is shift. Let's ignore the edge case where
        ; both (left & right) shift keys are pressed and one only is released.
        cp KB_LEFT_SHIFT
        jr z, _keyboard_extended_toggle_shift
        cp KB_RIGHT_SHIFT
        jr z, _keyboard_extended_toggle_shift
        jp _keyboard_read_ignore_no_update
_keyboard_extended_toggle_shift:
        ; Toggle the shift/caps bit
        ld hl, kb_flags
        ld a, (hl)
        xor 1 << KB_FLAG_SHIFT_BIT
        ld (hl), a
        jp _keyboard_read_ignore
_keyboard_extended_left_arrow:
        ; The cursor shall not be at the beginning of the line
        ld a, (hl)
        or a
        jp z, _keyboard_read_ignore
        dec (hl)
        ld a, '\b'
        call stdout_print_char
        jp _keyboard_read_ignore
_keyboard_extended_right_arrow:
        ; Shall not be at the end of the buffer
        ld a, (kb_buffer_size)
        cp (hl)
        jp z, _keyboard_read_ignore
        ; Get the cursor value and move it forward
        ld c, (hl)
        inc (hl)
        ; There is no equivalent for backspace, "space" would erase the character
        ; under the cursor. The solution is to get the character underneath and print
        ; it again.
        ld hl, kb_internal_buffer
        ld b, 0
        add hl, bc
        ld a, (hl)
        call stdout_print_char
        jp _keyboard_read_ignore
_keyboard_extended_up_arrow:
_keyboard_extended_down_arrow:
        ; Need to override the behavior when other modes than "cooked" available
        jp _keyboard_read_ignore


        ; Read from the keyboard FIFO directly and return the numbers of bytes
        ; written.
        ; Parameters:
        ;       DE - Destination buffer.
        ;       BC - Size to read in bytes. Guaranteed to be equal to or smaller than 16KB.
        ;            Bigger than 0.
        ; Returns:
        ;       A  - ERR_SUCCESS if success, error code else
        ;       BC - Number of bytes read.
        ; Alters:
        ;       This function can alter any register.
keyboard_read_raw:
        call wait_for_character
        ; To speed up the loop, if B is not 0, set C to 0xff. The keyboard FIFO
        ; is not that big.
        ld a, b
        or b
        jr z, _keyboard_read_raw_loop
        ld c, 0xff
        ; Remaining buffer size is C, written bytes is B
_keyboard_read_raw_loop:
        ; There is at least one character in the FIFO, retrieve it
        push bc
        call keyboard_next_pressed_key
        ex de, hl
        ; Check if it's a release event, if so, we have to add one more character
        ; in the user buffer.
        dec b
        ; Restore original infos
        pop bc
        jr nz, _keyboard_read_raw_pressed
        ld (hl), KB_RELEASED
        inc hl
        inc b   ; Increment the number of bytes received
        dec c   ; Decrement the remaining buffer size
        jr z, _keyboard_read_raw_loop_end
_keyboard_read_raw_pressed:
        ld (hl), a
        inc hl
        ; Put back the user buffer in DE as it won't be altered by keyboard_next_pressed_key
        ex de, hl
        inc b   ; Increment the number of bytes received
        ; Check if we still have some bytes in the keyboard FIFO
        ld a, (kb_fifo_size)
        or a
        jr z, _keyboard_read_raw_loop_end
        dec c   ; Decrement the remaining buffer size
        jr nz, _keyboard_read_raw_loop
_keyboard_read_raw_loop_end:
        ; End of the loop, either because the FIFO is now empty or because the user
        ; buffer is full.
        ; Return the size written (B) in BC
        ld c, b
        ld b, 0
        xor a
        ret


        ; Check and convert the character pressed to upper if in base scan table
        ; Parameters:
        ;   B - Character received
        ;   C - Scan table the character pressed was in
        ;   HL - Address of the character in base scan
        ; Returns:
        ;   B - Upper character
keyboard_switch_to_upper:
        ld a, c
        cp BASE_SCAN_TABLE
        ret nz
        ; Switch to upper scan table
        ld bc, upper_scan - base_scan
        add hl, bc
        ld b, (hl)
        ret

        ; Returns the next key pressed on the keyboard. If no key was pressed,
        ; it will wait for one.
        ; Parameters:
        ;       None
        ; Returns:
        ;       A - Pressed Key. If A is less than 128 (highest bit is 1),
        ;           it contains an ASCII character, else, it shall be compared
        ;           to the other characters code.
        ;       B - Event:
        ;            - KB_EVT_PRESSED
        ;            - KB_EVT_RELEASED
        ;       C - Scan table the character is in:
        ;            - BASE_SCAN_TABLE
        ;            - UPPER_SCAN_TABLE
        ;            - SPECIAL_TABLE
        ;            - EXT_SCAN_TABLE
        ;       HL - Address of the key pressed in the (base or special) scan
        ; Alters:
        ;       A, BC
        PUBLIC keyboard_next_pressed_key
keyboard_next_pressed_key:
        call wait_for_character
        call keyboard_dequeue
        ; Ignore FIFO empty, should not happen
        ld a, h
        cp KB_RELEASE_SCAN      ; Test if A is a "release" command
        jp z, _release_char
        ; Character is not a "release command"
        ; Check if the character is a printable char
        cp KB_PRINTABLE_CNT - 1
        jp nc, _special_code ; jp nc <=> A >= KB_PRINTABLE_CNT - 1
        ; Save the char in BC as it represents the index
        ld c, a
        ld b, 0
        ld hl, base_scan
        add hl, bc
        ld a, (hl)
        ; Return KB_EVT_PRESSED in B, BASE_SCAN_TABLE in C
        ld bc, KB_EVT_PRESSED << 8 | BASE_SCAN_TABLE
        ret
_release_char:
        call keyboard_next_pressed_key
        ld b, KB_EVT_RELEASED
        ret
_special_code:
        ; Load in HL special scan codes
        ; Special character is still in A
        cp KB_EXTENDED_SCAN
        jp z, _extended_code
        add -KB_SPECIAL_START
        ld b, 0
        ld c, a
        ld hl, special_scan
        add hl, bc
        ld a, (hl)
        ; Return KB_EVT_PRESSED in B, SPECIAL_SCAN_TABLE in C
        ld bc, KB_EVT_PRESSED << 8 | SPECIAL_SCAN_TABLE
        ret
_extended_code:
        ; In case the received character is a released (special) character
        ; ignore it the same way it is done normally
        call wait_for_character
        call keyboard_dequeue
        ; Ignore FIFO empty, should not happen
        ld a, h
        cp KB_RELEASE_SCAN
        jp z, _release_char
        ; For scan codes are particular:
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
        ld b, 0
        ld c, a
        ld hl, extended_scan
        add hl, bc
        ld a, (hl)
        ; Return KB_EVT_PRESSED in B, EXT_SCAN_TABLE in C
        ld bc, KB_EVT_PRESSED << 8 | EXT_SCAN_TABLE
        ret
_unmapped_ext_scans:
        ; Return KB_EVT_PRESSED in B, let's consider those as extended scans
        ld bc, KB_EVT_PRESSED << 8 | EXT_SCAN_TABLE
        cp KB_RIGHT_ALT_SCAN
        jp z, _right_alt_ret_rcved
        cp KB_RIGHT_CTRL_SCAN
        jp z, _right_ctrl_rcved
        cp KB_NUMPAD_DIV_SCAN
        jp z, _numpad_div_rcved
        cp KB_LEFT_SUPER_SCAN
        jp z, _left_super_rcved
        cp KB_NUMPAD_RET_SCAN
        jp z, _numpad_ret_rcved
        cp KB_PRT_SCREEN_SCAN
        jp z, _print_screen_rcved
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
        call wait_for_character
        call keyboard_dequeue
        call wait_for_character
        call keyboard_dequeue
        ld a, KB_PRINT_SCREEN
        ret

        ; Wait for a keyboard key to be pressed.
        ; Returns:
        ;       A - New size of the keyboard FIFO
        ; Alters:
        ;       A
wait_for_character:
        ; If no char in the FIFO, wait for interrupt
        ld a, (kb_fifo_size)
        and a                ; Update flags
        ret nz
        halt
        jp wait_for_character

base_scan:
        DEFB 0, KB_F9, 0, KB_F5, KB_F3, KB_F1, KB_F2, KB_F12, 0, KB_F10, KB_F8, KB_F6, KB_F4, '\t', '`', 0
        DEFB 0, KB_LEFT_ALT, KB_LEFT_SHIFT, 0, KB_LEFT_CTRL, 'q', '1', 0, 0, 0, 'z', 's', 'a', 'w', '2', 0
        DEFB 0, 'c', 'x', 'd', 'e', '4', '3', 0, 0, ' ', 'v', 'f', 't', 'r', '5', 0
        DEFB 0, 'n', 'b', 'h', 'g', 'y', '6', 0, 0, 0, 'm', 'j', 'u', '7', '8', 0
        DEFB 0, ',', 'k', 'i', 'o', '0', '9', 0, 0, '.', '/', 'l', ';', 'p', '-', 0
        DEFB 0, 0, '\'', 0, '[', '=', 0, 0, KB_CAPS_LOCK, KB_RIGHT_SHIFT, '\n', ']', 0, '\\'
upper_scan:
        DEFB 0, KB_F9, 0, KB_F5, KB_F3, KB_F1, KB_F2, KB_F12, 0, KB_F10, KB_F8, KB_F6, KB_F4, '\t', '~', 0
        DEFB 0, KB_LEFT_ALT, KB_LEFT_SHIFT, 0, KB_LEFT_CTRL, 'Q', '!', 0, 0, 0, 'Z', 'S', 'A', 'W', '@', 0
        DEFB 0, 'C', 'X', 'D', 'E', '$', '#', 0, 0, ' ', 'V', 'F', 'T', 'R', '%', 0
        DEFB 0, 'N', 'B', 'H', 'G', 'Y', '^', 0, 0, 0, 'M', 'J', 'U', '&', '*', 0
        DEFB 0, '<', 'K', 'I', 'O', ')', '(', 0, 0, '>', '?', 'L', ':', 'P', '_', 0
        DEFB 0, 0, '"', 0, '{', '+', 0, 0, KB_CAPS_LOCK, KB_RIGHT_SHIFT, '\n', '}', 0, '|'
special_scan:
        DEFB '\b', 0, 0, KB_NUMPAD_1, 0, KB_NUMPAD_4, KB_NUMPAD_7, 0, 0, 0, KB_NUMPAD_0
        DEFB KB_NUMPAD_DOT, KB_NUMPAD_2, KB_NUMPAD_5, KB_NUMPAD_6, KB_NUMPAD_8, KB_ESC
        DEFB KB_NUMPAD_LOCK, KB_F11, KB_NUMPAD_PLUS, KB_NUMPAD_3, KB_NUMPAD_MINUS, KB_NUMPAD_MUL
        DEFB KB_NUMPAD_9, KB_SCROLL_LOCK, 0, 0, 0, 0, KB_F7, 0, 0
extended_scan:
        DEFB KB_END, 0, KB_LEFT_ARROW, KB_HOME, 0, 0, 0, KB_INSERT, KB_DELETE, KB_DOWN_ARROW
        DEFB 0, KB_RIGHT_ARROW, KB_UP_ARROW, 0, 0, 0, 0, KB_PG_DOWN, 0, 0, KB_PG_UP

        ; Enqueue a value in the FIFO. If the FIFO is full, the oldest value
        ; will be overwritten.
        ; Parameters:
        ;       A - Value to enqueue
        ; Returns:
        ;       None
        ; Alters:
        ;       A, HL
        PUBLIC keyboard_interrupt_handler
keyboard_interrupt_handler:
        ; In the keyboard interrupt handler, we will retrieve the key that has just been
        ; pressed and put it in our FIFO
        in a, (KB_IO_ADDRESS)
keyboard_enqueue:
        ld hl, (kb_fifo_wr)
        ld (hl), a
        ; Increment HL. We know that HL is aligned on KEYBOARD_FIFO_SIZE.
        ; So L can be incremented alone, but keep the upper bit like
        ; they are in the FIFO address
        inc l
        ld a, l
        ; And A with the upper bits of L that shall not change
        ; For example, when HL is aligned on 16, L upper nibble
        ; must not change, thus we should have A AND 0xNF where
        ; N = L upper nibble
        and KEYBOARD_FIFO_SIZE - 1
        add kb_fifo & 0xff
        ld (kb_fifo_wr), a
        ; Check if the size needs update (i.e. FIFO not full)
        ld a, (kb_fifo_size)
        cp KEYBOARD_FIFO_SIZE
        ; In case the FIFO is full, we need to push read cursor forward
        jr z, _keyboard_queue_next_read
        ; Else, simply increment the size
        inc a
        ld (kb_fifo_size), a
        ret
_keyboard_queue_next_read:
        ld a, l
        ld (kb_fifo_rd), a
        ret


        ; Dequeue a value from the FIFO. If the FIFO is empty,
        ; A will not be 0
        ; Parameters:
        ;       None
        ; Returns:
        ;       A - Non-zero value on success, 0 if FIFO empty
        ;       H - Value dequeued if A is success
        ; Alters:
        ;       A, HL
keyboard_dequeue:
        ld hl, kb_fifo_size
        ; The following needs to be a critical section in order to prevent
        ; a size corruption.
        ; Indeed, let's say ld a, (hl), loads 5 in A; a keyboard interrupt
        ; occurs, set the size to 6, we come back to the current routine
        ; decrement A, it becomes 4, and set it in kb_fifo_size, then
        ; we would have lost a byte!
        ; Disable interrupt to prevent this to happen.
        xor a
        ENTER_CRITICAL()
        or (hl)
        jp nz, _keyboard_dequeue_notempty
        EXIT_CRITICAL()
        ret
_keyboard_dequeue_notempty:
        dec (hl)
        ; We can now read safely from the FIFO, as we have our proper
        ; pointer to read, and because we are the only reader of the FIFO
        ; no need to do this in a critical section.
        ld hl, (kb_fifo_rd)
        ld h, (hl)
        ; Increment L, the same way we did in enqueue
        inc l
        ld a, l
        and KEYBOARD_FIFO_SIZE - 1
        add kb_fifo & 0xff
        ld (kb_fifo_rd), a      ; Update lowest byte
        EXIT_CRITICAL()
        ret


        SECTION DRIVER_BSS
kb_fifo_wr: DEFS 2
kb_fifo_rd: DEFS 2
kb_fifo_size: DEFS 1
        ; Check `keyboard_h.asm` file for all flags
kb_flags: DEFS 1
kb_internal_buffer: DEFS KEYBOARD_INTERNAL_BUFFER_SIZE
        ASSERT(KEYBOARD_INTERNAL_BUFFER_SIZE < 256)
kb_buffer_size: DEFS 1
        ; Index of the cursor in the internal buffer
        ; 0 <= cursor <= KEYBOARD_INTERNAL_BUFFER_SIZE - 1
kb_buffer_cursor: DEFS 1

        SECTION DRIVER_BSS_ALIGN16
        ALIGN 16
kb_fifo: DEFS KEYBOARD_FIFO_SIZE
        ; The FIFO size must be a power of two, and be less or equal to 256
        ASSERT(KEYBOARD_FIFO_SIZE != 0 && KEYBOARD_FIFO_SIZE <= 256)
        ASSERT((KEYBOARD_FIFO_SIZE & (KEYBOARD_FIFO_SIZE - 1)) == 0)



        SECTION KERNEL_DRV_VECTORS
this_struct:
NEW_DRIVER_STRUCT("KEYB", \
                  keyboard_init, \
                  keyboard_read, keyboard_write, \
                  keyboard_open, keyboard_close, \
                  keyboard_seek, keyboard_ioctl, \
                  keyboard_deinit)
