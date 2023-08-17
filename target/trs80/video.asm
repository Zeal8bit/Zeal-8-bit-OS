; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "errors_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "video_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "time_h.asm"
        INCLUDE "strutils_h.asm"


        SECTION KERNEL_DRV_TEXT
        ; Initialize the video driver.
        ; This is called only once, at boot up
video_init:
        ; Initialize the non-0 values here, others are already set to 0 because
        ; they are in the BSS section, including cursor_y and cursor_x.
        ld hl, IO_VIDEO_VIRT_TEXT_VRAM
        ld (cursor_pos), hl

        ; Empty the whole screen
        ld d, h
        ld e, l
        inc de
        ld (hl), ' '
        ld bc, IO_VIDEO_MAX_CHAR - 1
        ldir

        ; Set it at the default stdout
        ld hl, this_struct
        call zos_vfs_set_stdout

video_deinit:
video_open:
        xor a   ; Success
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
video_ioctl:
        ld a, c
        ; Check that C is in the range [0;CMD_COUNT[
        cp CMD_COUNT
        jr nc, _video_invalid_param
        ; Get the label to jump to
        ld hl, _video_ioctl_cmd_table
        rlca    ; A *= 2
        ADD_HL_A()
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        jp (hl)
_video_invalid_param:
        ld a, ERR_INVALID_PARAMETER
        ret

        ; Get video driver attributes, including, video modes supported,
        ; colors supported, scrolling supported, current scrolling count,
        ; etc...
_video_ioctl_get_attr:
_video_ioctl_set_attr:
        jp _video_not_impl


        ; Get current mode area size, DE represent a pointer to area_t structure
_video_ioctl_get_area:
        ex de, hl
        ld (hl), IO_VIDEO_X_MAX
        inc hl
        ld (hl), IO_VIDEO_Y_MAX
        inc hl
        ld (hl), IO_VIDEO_MAX_CHAR & 0xff
        inc hl
        ld (hl), IO_VIDEO_MAX_CHAR >> 8
        ex de, hl
        ret


        ; Return the cursor position (x,y) in registers D and E respectively
        ; Returns:
        ;   DE - Address to fill with X and Y. The buffer must be at least
        ;        16-bit big.
        ; Alters:
        ;   A, HL, DE
_video_ioctl_get_cursor_xy:
        ld hl, cursor_x
        ld a, (hl)
        ld (de), a
        sub IO_VIDEO_X_MAX
        jr nz, _video_ioctl_get_cursor_xy_no_reset
        ld (de), a
_video_ioctl_get_cursor_xy_no_reset:
        inc hl
        inc de
        ld a, (hl)
        ld (de), a
        sub IO_VIDEO_Y_MAX - 1
        ; We have to return 0 in all cases to mark the ioctl as a success
        ld a, 0
        ret nz
        ld (de), a
        ret


        ; Set the position (x,y) of the cursor. If X or Y is bigger than
        ; the maximum, they will be set to the maximum.
        ; Parameters:
        ;   D - New X position
        ;   E - New Y position
        ; Alters:
        ;   A, BC, DE, HL
_video_ioctl_set_cursor_xy:
        push de
        ; Hide the cursor as it is going be to repositioned
        call video_hide_cursor
        pop de
        ; Load the maximum Y possible
        ld bc, IO_VIDEO_X_MAX << 8 | IO_VIDEO_Y_MAX
        ; If Y is bigger than IO_VIDEO_Y_MAX, set it to IO_VIDEO_Y_MAX - 1
        ld a, e
        cp c
        jr c, _video_ioctl_set_cursor_y_valid
        ; Set E to the maximum - 1
        ld e, c
        dec e
_video_ioctl_set_cursor_y_valid:
        ld (cursor_y), a
        ; Store Y in L
        ld l, a
        ; Do the same adjustment for X
        ld a, d
        cp b
        jr c, _video_ioctl_set_cursor_x_valid
        ld a, b
        dec a
_video_ioctl_set_cursor_x_valid:
        ld (cursor_x), a
        ld d, a
        ; D and L contain respectively X and Y coordinates now
        ; HL = Y * 64 (IO_VIDEO_X_MAX) + X
        ld h, 0
        add hl, hl  ; * 2
        add hl, hl  ; * 4
        add hl, hl  ; * 8
        add hl, hl  ; * 16
        add hl, hl  ; * 32
        add hl, hl  ; * 64

        ld a, d ; A = position X
        ld d, IO_VIDEO_VIRT_TEXT_VRAM >> 8
        ld e, a
        add hl, de
        ld (cursor_pos), hl
        call video_show_cursor
        ; Success, return 0
        xor a
        ret


        ; Set the current background and foreground color.
        ; It is not guaranteed that the color chosen is available.
        ; Parameters:
        ;   D - Background color
        ;   E - Foreground color
        ; Returns:
        ;   A - 0 on success
_video_ioctl_set_colors:
        ld a, ERR_NOT_SUPPORTED
        ret


        ; Clear the screen (with current color) and reposition the cursor.
        ; Parameters:
        ;   None
        ; Returns:
        ;   A - 0 on success
        ; Alters:
        ;   A, BC, DE, HL
_video_ioctl_clear_screen:
        ; Clear the screen characters by writing 0 to the VRAM text part
        ld hl, IO_VIDEO_VIRT_TEXT_VRAM
        ld bc, IO_VIDEO_MAX_CHAR
        xor a
        call _video_vram_set
        ; Screen has been cleared, reset the absolute cursor to position 0
        ld hl, IO_VIDEO_VIRT_TEXT_VRAM
        ld (cursor_pos), hl
        ; Show the cursor
        ld (hl), '_'
        ; Save the new (X,Y) position
        ld hl, 0
        ld (cursor_x), hl
        ; Show the cursor at its new position
        xor a
        ret

        ; Parameters:
        ;   HL - Address of the memory to set
        ;   BC - Size of the memory
        ;   A - Data to write to it
_video_vram_set:
        ld d, a
_video_vram_set_loop:
        ld (hl), d
        inc hl
        dec bc
        ld a, b
        or c
        jp nz, _video_vram_set_loop
        ret


_video_ioctl_cmd_table:
        DEFW _video_ioctl_get_attr
        DEFW _video_ioctl_get_area
        DEFW _video_ioctl_get_cursor_xy
        DEFW _video_ioctl_set_attr
        DEFW _video_ioctl_set_cursor_xy
        DEFW _video_ioctl_set_colors
        DEFW _video_ioctl_clear_screen


        ; Write function, called every time user application needs to output chars
        ; or pixels to the video chip.
        ; Parameters:
        ;       A  - DRIVER_OP_HAS_OFFSET (0) if the stack has a 32-bit offset to pop
        ;            DRIVER_OP_NO_OFFSET  (1) if the stack is clean, nothing to pop.
        ;       DE - Source buffer. Guaranteed to not cross page boundary.
        ;       BC - Size to read in bytes. Guaranteed to be equal to or smaller than 16KB.
        ;
        ;       ! IF AND ONLY IF A IS 0: !
        ;       Top of stack: 32-bit offset. MUST BE POPPED IN THIS FUNCTION.
        ;              [SP]   - Upper 16-bit of offset
        ;              [SP+2] - Lower 16-bit of offset
        ; Returns:
        ;       A  - ERR_SUCCESS if success, error code else
        ;       BC - Number of bytes written
        ; Alters:
        ;       This function can alter any register.
video_write:
        push bc
        call print_buffer
        call video_show_cursor
        pop bc
        ; Return success
        xor a
        ret

        ; Read not supported yet.
        ; Same reasons as above, stack is clean
video_read:

        ; Close an opened dev number.
        ; Parameter:
        ;       A  - Opened dev number getting closed
        ; Returns:
        ;       A - ERR_SUCCESS if success, error code else
        ; Alters:
        ;       A, BC, DE, HL
video_close:

        ; Move the abstract cursor to a new position.
        ; The new position is a 32-bit value, it can be absolute or relative
        ; (to the current position or the end), depending on the WHENCE parameter.
        ; Parameters:
        ;       H - Opened dev number getting seeked.
        ;       BCDE - 32-bit offset, signed if whence is SEEK_CUR/SEEK_END.
        ;              Unsigned if SEEK_SET.
        ;       A - Whence. Can be SEEK_CUR, SEEK_END, SEEK_SET.
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else.
        ;       BCDE - Unsigned 32-bit offset. Resulting offset.
        ; Alters:
        ;       A, BC, DE, HL
video_seek:

_video_not_impl:
        ld a, ERR_NOT_IMPLEMENTED
        ret


        ;======================================================================;
        ;================= S T D O U T     R O U T I N E S ====================;
        ;======================================================================;

        ; Show the cursor.
        ; beforehand.
        ; Parameters:
        ;       None
        ; Returns:
        ;       None
        ; Alters:
        ;       A, HL, DE
        PUBLIC stdout_show_cursor
        PUBLIC video_show_cursor
stdout_show_cursor:
video_show_cursor:
        ld hl, (cursor_pos)
        ld (hl), '_'
        ret

        ; Hide the cursor.
        ; The routine video_map_start must have been called
        ; beforehand.
        ; Parameters:
        ;       None
        ; Returns:
        ;       None
        ; Alters:
        ;       A, HL, DE
        PUBLIC video_hide_cursor
        PUBLIC stdout_hide_cursor
stdout_hide_cursor:
video_hide_cursor:
        ret


        ; Print a buffer from the current cursor position, but without
        ; updating the cursor position at the end of the operation.
        ; The characters in the buffer must all be printable characters,
        ; as they will be copied as-is on the screen.
        ; The buffer must not be in the second memory page.
        ; NOTE: The routine video_map_start must have been called beforehand
        ; Parameters:
        ;       DE - Buffer containing the chars to print
        ;       BC - Buffer size to render
        ; Returns:
        ;       None
        ; Alters:
        ;       A, BC, HL, DE
        PUBLIC stdout_print_buffer
        PUBLIC video_print_buffer_from_cursor
stdout_print_buffer:
video_print_buffer_from_cursor:
        ld hl, (cursor_pos)
        ; The cursor becomes the destination
        ex de, hl
        ldir
        jr video_show_cursor



        PUBLIC stdout_print_char
stdout_print_char:
        call print_char
        jp video_show_cursor


        ;======================================================================;
        ;================= P R I V A T E   R O U T I N E S ====================;
        ;======================================================================;


        ; Print a buffer on the screen
        ; Parameters:
        ;       DE - Character buffer to print
        ;       BC - Size of the buffer
        ; Alters:
        ;       A, BC, DE, HL
print_buffer:
        ld a, b
        or c
        ret z
        ld a, (de)
        call print_char
        inc de
        dec bc
        jp print_buffer


        ; Print a character at the cursors positions (cursor_x and cursor_y)
        ; The cursors will be updated accordingly. If the end of the screen
        ; is reached, the cursor will go back to the beginning.
        ; New line (\n) will make the cursor jump to the next line.
        ;
        ; Parameter:
        ;       A - ASCII character to output
        ;       DE - Address of the ASCII char (A)
        ;       BC - Size of the string pointed by DE
        ; Returns:
        ;       DE - New address of the string (if esc sequences)
        ;       BC - New size of the string pointed by DE (if esc sequences)
        ; Alters:
        ;       A, BC, HL
        PUBLIC print_char
print_char:
        or a
        ret z   ; NULL-character, don't do anything
        cp '\n'
        jr z, _print_char_newline
        cp '\r'
        jr z, _print_char_carriage_return
        cp '\b'
        jr z, _print_char_backspace
        ; Tabulation is consider a space. Do nothing special.
        ; Get the cursor position
        push af
        call _video_adjust_cursor
        pop af
        ld hl, (cursor_pos)
        ld (hl), a              ; Write the ASCII character to VRAM
        inc hl
        ld (cursor_pos), hl     ; Save incremented position
        ; Now, we also need to increment the position-on-current-line byte
        ld hl, cursor_x
        inc (hl)
        ret
_print_char_newline:
        ; Before resetting cursor_x, let's make cursor_pos point to next line!
        ; Perform cursor_pos += IO_VIDEO_X_MAX - cursor_x
        ld a, (cursor_x)
        neg
        add IO_VIDEO_X_MAX
        ld hl, (cursor_pos)
        ADD_HL_A()
        ld (cursor_pos), hl
        ld hl, cursor_x
        jp _video_force_adjust_cursor
_print_char_carriage_return:
        ; This is similar to newline, expect that we subtract what has been reached
        ; cursor_x, instead of adding remaining chars
        ld hl, cursor_x
        ld a, (hl)
        ; Reset cursor_x now as we are currently pointing to it
        ld (hl), 0
        neg
        ld hl, (cursor_pos)
        ; We can add A to HL but we need to decrement H first as A is negative
        dec h
        ADD_HL_A()
        ld (cursor_pos), hl
        ret
_print_char_backspace:
        ; It is unlikely that X is 0 and even more unlikely that Y is too
        ; so save some time for the "best" case and decrement HL here
        ld hl, (cursor_pos)
        dec hl
        ld (cursor_pos), hl
        ; Check if cursor_x is 0
        ld hl, cursor_x
        ld a, (hl)
        ; Decrement cursor_x in case it's not 0 (likely)
        dec (hl)
        ; Check if it was 0 before decrementing
        or a
        ret nz
        ; X was 0, roll it to X maximum
        ld a, IO_VIDEO_X_MAX - 1
        ld (hl), a
        ; Check if cursor_y is also
        ; ASSERT(cursor_y == cursor_x + 1)
        inc hl
        ; Same with cursor_y
        ld a, (hl)
        dec (hl)
        or a
        ret nz
        ; Y is also 0, we have to roll it back, same for cursor_pos
        ld a, IO_VIDEO_Y_MAX - 1
        ld (hl), a
        ; Also reset the absolute cursor
        ld hl, IO_VIDEO_VIRT_TEXT_VRAM + IO_VIDEO_MAX_CHAR - 1
        ld (cursor_pos), hl
        ret


        ; Must not alter BC nor DE
_video_adjust_cursor:
        ; Check if the current X is out of bound
        ld hl, cursor_x
        ld a, (hl)
        cp IO_VIDEO_X_MAX
        ; Nothing special in the case where X has not reached the end of the screen
        ret nz
_video_force_adjust_cursor:
        ; X reached the end of the line, reset it
        ld (hl), 0
        ; Update Y position to go to the next line (&cursor_y + 1 == &cursor_x)
        inc hl
        ; Set the cursors back to 0 in case we reached the maximum, again
        ld a, (hl)
        cp IO_VIDEO_Y_MAX - 1
        ; If Y has not reached the maximum, no need to reset absolute cursor, nor scroll
        ret nz
        ; Set the absolute cursors to the last line as we reached the maximum
        ld hl, IO_VIDEO_VIRT_TEXT_VRAM + IO_VIDEO_MAX_CHAR - IO_VIDEO_X_MAX
        ld (cursor_pos), hl
        ; Scroll the screen vertically by 1 line
        push de
        push bc
        ld hl, IO_VIDEO_VIRT_TEXT_VRAM + IO_VIDEO_X_MAX
        ld de, IO_VIDEO_VIRT_TEXT_VRAM
        ld bc, IO_VIDEO_MAX_CHAR - IO_VIDEO_X_MAX
        ldir
        ; DE points to the last line, which we should clean
        xor a
_erase_line_loop:
        ld (de), a
        inc de
        djnz _erase_line_loop
        pop bc
        pop de
        ret


        SECTION DRIVER_BSS
cursor_pos:    DEFS 2  ; 2 bytes for cursor position on the screen
cursor_x:      DEFS 1  ; 1 byte for cursor X position (current column)
cursor_y:      DEFS 1  ; 1 byte for cursor Y position, must follow x


        SECTION KERNEL_DRV_VECTORS
this_struct:
NEW_DRIVER_STRUCT("VID0", \
                  video_init, \
                  video_read, video_write, \
                  video_open, video_close, \
                  video_seek, video_ioctl, \
                  video_deinit)
