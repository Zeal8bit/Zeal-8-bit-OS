; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "zos_sys.asm"
        INCLUDE "zos_video.asm"
        INCLUDE "zos_keyboard.asm"

        SECTION TEXT

        DEFC FILENAME_SIZE = 16
        DEFC PAGE3_ADDR    = 0x8000
        DEFC PAGE3_SIZE    = 16384

        ; A static buffer that can be used across the commands implementation
        EXTERN init_static_buffer
        EXTERN init_static_buffer_end
        EXTERN error_print

        DEFC INIT_BUFFER_SIZE = init_static_buffer_end - init_static_buffer
        DEFC COMMAND_QUIT        = KB_KEY_Q
        DEFC COMMAND_SCROLL_UP   = KB_UP_ARROW
        DEFC COMMAND_SCROLL_DOWN = KB_DOWN_ARROW

        ; "less" command main function
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        PUBLIC less_main
less_main:
        ; Check that argc is 2 (command itself is part of argc)
        ld a, c
        cp 2
        jp nz, _less_usage
        ; Retrieve the filename given as a parameter
        inc hl
        inc hl  ; skip the first pointer
        ld c, (hl)
        inc hl
        ld b, (hl)
        ; Filepath in BC now, open the file
        ; BC - Path to file
        ; H - Flags
        ld h, O_RDONLY
        OPEN()
        or a
        ; In this case, A is negative if an error occurred
        jp m, open_error
        ; Save the file descriptor
        ld (file_fd), a
        ; Get the number of characters on screen
        call get_screen_characters_count
        or a
        jr nz, ioctl_error
        ; Set the input to RAW
        call set_stdin_mode
        jr nz, ioctl_error
        ; Reset the print buffer by simulating a CR
        call print_char_cr
        ; Save the number of characters on screen
        ld a, (file_fd)
        ld h, a
        ; FIXME: Use the global buffer instead of the third page, to allow files
        ; bigger than 16KB
        ld de, PAGE3_ADDR
        ld (buffer_from), de
        ld bc, PAGE3_SIZE
        READ()
        ; Check for a potential error
        or a
        jp nz, read_error
        ; Save the number of characters read (file size)
        ld hl, PAGE3_ADDR
        add hl, bc
        ld (buffer_filled), hl
_less_clear_and_print:
        ; Clear the screen and print the characters from the file
        call clear_set_cursor
        or a
        jr nz, ioctl_error
        call print_buffer
        ; Set the cursor to the bottom of the screen and listen on the keyboard
_less_wait_command:
        call listen_on_input
        ; Check the input character
        cp COMMAND_QUIT
        jr z, _less_end
        cp COMMAND_SCROLL_UP
        jr z, _less_scroll_up
        cp COMMAND_SCROLL_DOWN
        jr z, _less_scroll_down
        ; Unknown command, try again
        jr _less_wait_command
_less_scroll_up:
        call scroll_up
        jr _less_clear_and_print
_less_scroll_down:
        call scroll_down
        jr _less_clear_and_print
_less_end:
        ; On exit, clear the screen and set the cursor back
        call clear_set_cursor
        ld a, (file_fd)
        ld h, a
        ; Close the opened file
        CLOSE()
        xor a
        ret


_less_usage:
        S_WRITE3(DEV_STDOUT, str_usage, str_usage_end - str_usage)
        ld a, 1
        ret

ioctl_error:
        ld de, str_ioctl_err
        ld bc, str_ioctl_err_end - str_ioctl_err
        jr print_error
open_error:
        ; The error is negated
        neg
        ld de, str_open_err
        ld bc, str_open_err_end - str_open_err
        jr print_error
read_error:
        ; We have to close the file dev which is in h, save A as it contains
        ; the real error that occurred
        ld b, a
        CLOSE()
        ; Ignore the potential error from close
        ld a, b
        ld de, str_read_err
        ld bc, str_read_err_end - str_read_err
print_error:
        call error_print
        ; Return an error in any case
        ld a, 3
        ret


        ; Set stdin to RAW to be able to capture all key presses
set_stdin_mode:
        ld h, DEV_STDIN
        ld c, KB_CMD_SET_MODE
        ld e, KB_MODE_RAW
        IOCTL()
        ret


        ; Clear the screen and set the cursor to the top left
        ; Parameters:
        ;   None
clear_set_cursor:
        ld h, DEV_STDOUT
        ; Clear the screen
        ld c, CMD_CLEAR_SCREEN
        IOCTL()
        or a
        ret nz
        ; Set the cursor position to the top left
        ld c, CMD_SET_CURSOR_XY
        ld de, 0
        IOCTL()
        ret


        ; Get the number of characters on screen
        ; Parameters:
        ;   None
        ; Returns:
        ;   A - 0 on success, error code else
get_screen_characters_count:
        ld de, screen_area
        ld c, CMD_GET_AREA
stdout_ioctl:
        ld h, DEV_STDOUT
        IOCTL()
        or a
        ret


        ; Return the number of characters shown on screen
        ; Parameters:
        ;   None
        ; Returns:
        ;   BC - Number of characters shown on screen/remaining in the buffer
        ;   Z flag - set if result is 0
get_current_buffer_size:
        ; Check the number of bytes remaining in the buffer
        ld de, (buffer_from)
        ld hl, (buffer_filled)
        or a
        sbc hl, de
        ; Save this number in BC
        ld b, h
        ld c, l
        ret


        ; Scroll the screen down by looking for the next \n character in the buffer. Let's allow scrolling, even if
        ; the file doesn't reach the bottom of the screen, this will ease the algorithm since we don't need to perform
        ; any further check.
        ; Parameters:
        ;   None
        ; Returns:
        ;   [buffer_from] - Address of the next line
scroll_down:
        call get_current_buffer_size
        ret z
        ; Look for the next new line character
        ld hl, (buffer_from)
        ld a, '\n'
        cpir
        ; If Z is set, we found a newline and the HL points to the character right after
        ; else, we didn't find it, we can return, we cannot scroll further down
        ret nz
        ld (buffer_from), hl
        ret


        ; Scroll the screen up by looking for the previous \n character in the buffer.
        ; Parameters:
        ;   None
        ; Returns:
        ;   [buffer_from] - Address of the previous line
scroll_up:
        ; Check if the buffer isn't already at the top
        ld de, (buffer_from)
        ld hl, -PAGE3_ADDR
        ; Add doesn't affect Z flag, ADC does...
        or a
        adc hl, de
        ret z   ; Already at the top if both are equal
        ; Put buffer_from back at in HL, DE contains the size
        ex de, hl
        ld b, d
        ld c, e
        ; Look for the previous new line character, BEFORE the current line
        dec hl  ; should point to '\n'
        dec bc
        ; If BC is 0, the file starts with a \n directly, e.g. "\nb"
        ld a, b
        or c
        jr z, _scroll_up_store
        dec hl  ; should point to the last character of the previous line
        dec bc
        ; If BC is 0, the file starts with a 2-character line, e.g. "a\nb"
        ld a, b
        or c
        jr z, _scroll_up_store
        ld a, '\n'
        cpdr
        ; If Z is set, we found a newline and the HL points to the character right before
        ; else, we didn't find it, HL points to the beginning of the buffer
        jr nz, _scroll_up_store
        inc hl ; points to \n
        inc hl ; points to the previous line first character
_scroll_up_store:
        ld (buffer_from), hl
        ret

        ; Print the characters starting from `buffer_from`
print_buffer:
        call get_current_buffer_size
        ret z
        ; Iterate over the buffer and estimate how many bytes we have to show on screen.
        ; We must not go out of bounds. D = X coordinates, E = Y coordinates
        ld hl, 0
        ex de, hl
_print_buffer_loop:
        ld a, (hl)
        inc hl
        dec bc
        cp '\r'
        jr z, _print_buffer_cr
        cp '\n'
        jr z, _print_buffer_nl
        ; TODO: Support \b ?
        ; Else, nothing special, print the character
        call print_char
        ; If D has reached the end of the screen, increment Y and skip the rest of the line
        inc d
        ; A = screen width
        ld a, (screen_area)
        cp d
        jr nz, _print_buffer_check_bc
        ; Reached the max width of the screen, skip characters until BC is 0 or HL is '\n'
        ld a, '\n'
        cpir
        ; If flag is not zero, the character was not found, which means we reached the end of the file
        ret nz
        ; Treat it as if a \n was found
        jr _print_buffer_nl_no_print
_print_buffer_cr:
        ld d, 0
        call print_char_cr
        jr _print_buffer_check_bc
_print_buffer_nl:
        call print_char
_print_buffer_nl_no_print:
        ld d, 0
        inc e
        call print_flush
        ; A = screen height
        ld a, (screen_area + 1)
        dec a
        ; If E reached the last line, return
        cp e
        ret z
_print_buffer_check_bc:
        ld a, b
        or c
        jr nz, _print_buffer_loop
        ret

        ; Reset the buffer pointer
        ; Alters:
        ;   A
print_char_cr:
        push hl
        ld hl, init_static_buffer
        ld (init_static_buffer_from), hl
        pop hl
        ret


        ; Print a character to the current buffer
        ; Parameters:
        ;   A - Character to print
        ; Alters:
        ;   None
print_char:
        push hl
        ld hl, (init_static_buffer_from)
        ld (hl), a
        inc hl
        ld (init_static_buffer_from), hl
        pop hl
        ret


        ; Flush the current buffer to the output
        ; Parameters:
        ;   None
        ; Alters:
        ;   A
print_flush:
        push bc
        push de
        push hl
        ld hl, (init_static_buffer_from)
        ld de, -init_static_buffer
        add hl, de
        ; HL contains the size, put it in BC
        ld b, h
        ld c, l
        ld de, init_static_buffer
        ; Reset the buffer index
        ld (init_static_buffer_from), de
        S_WRITE1(DEV_STDOUT)
        ; TODO: Check the errors?
        pop hl
        pop de
        pop bc
        ret

        ; Wait for input from the user
        ; Parameters:
        ;   None
        ; Returns:
        ;   A - First character of the buffer, 0 if nothing
listen_on_input:
        ; Set the cursor to the last line
        ld a, (screen_area + 1)
        dec a
        ld d, 0
        ld e, a
        ; Set the cursor
        ld c, CMD_SET_CURSOR_XY
        call stdout_ioctl
        or a
        ret nz
        ; TODO: Check the errors?
        ; Read the command from the standard input
        ld de, init_static_buffer
        ld bc, INIT_BUFFER_SIZE
        ld h, DEV_STDIN
        READ()
        ; BC should not be 0 since we are in blocked mode
        ; Only consider the first caracter, ignore the potential release key
        ld a, (de)
        ret


str_usage: DEFM "usage: less <path_to_file>\n"
str_usage_end:
str_open_err: DEFM "open error: "
str_open_err_end:
str_read_err: DEFM "read error: "
str_read_err_end:
str_ioctl_err: DEFM "ioctl error: "
str_ioctl_err_end:

    SECTION BSS
file_fd: DEFS 1
screen_area: DEFS area_end_t
    ; Number of bytes stored in the buffer / file size
buffer_filled: DEFS 2
    ; Address of the buffer to start displaying from
buffer_from: DEFS 2
    ; Print buffer, using the shared buffer
init_static_buffer_from: DEFS 2
init_static_buffer_size: DEFS 1
