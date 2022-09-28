; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "errors_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "video_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "time_h.asm"
        INCLUDE "strutils_h.asm"

        EXTERN zos_sys_reserve_page_1
        EXTERN zos_sys_restore_pages
        EXTERN zos_vfs_set_stdout

        DEFC ESC_CODE = 0x1b

        SECTION KERNEL_DRV_TEXT
        ; Initialize the video driver.
        ; This is called only once, at bootup
video_init:
        ; We will need to scroll the screen when cursor_pos reaches
        ; 0 (IO_VIDEO_MAX_CHAR + 1 rolled).
        ; This value will be updated accordingly.
        ld hl, 0
        ld (scroll_at_pos), hl
        ; Other values will be reset to 0 as they are in the BSS

        ld a, TEXT_MODE_640
        out (IO_VIDEO_SET_MODE), a

        xor a
        out (IO_VIDEO_SCROLL_Y), a
        ld (scroll_count), a

        ld a, DEFAULT_CHARS_COLOR
        out (IO_VIDEO_SET_COLOR), a
        ld (chars_color), a

        ld a, DEFAULT_CHARS_COLOR_INV
        ld (invert_color), a
        
        ; Set it at the default stodut
        ld hl, this_struct
        call zos_vfs_set_stdout

        ; Register the timer-related routines
        IF VIDEO_USE_VBLANK_MSLEEP
        ld bc, video_msleep
        ELSE
        ld bc, 0
        ENDIF
        ld hl, video_set_vblank
        ld de, video_get_vblank

        ; Tail-call to zos_time_init
        jp zos_time_init

        ; Print a message on the video output
        ;MMU_MAP_PHYS_ADDR(MMU_PAGE_1, IO_VIDEO_PHYS_ADDR_TEXT)
video_deinit:
        ld a, ERR_SUCCESS
        ret

        ; Open function, called everytime a file is opened on this driver
        ; Note: This function should not attempt to check whether the file exists or not,
        ;       the filesystem will do it. Instead, it should perform any preparation
        ;       (if needed) as multiple reads will occur.
        ; Parameters:
        ;       BC - Name of the file to open
        ;       A  - Flags
        ;       (D  - In case of a driver, dev number opened)
        ; Returns:
        ;       A - ERR_SUCCESS if success, error code else
        ; Alters:
        ;       A, BC, DE, HL (any of them can be altered, caller-saved)
video_open:
        ; Restore the color to default. In the future, we'll also have to restore
        ; the default color palette and charset.
        ld a, DEFAULT_CHARS_COLOR
        call set_chars_color
        ret

        ; Perform an I/O requested by the user application.
        ; Parameters:
        ;       B - Dev number the I/O request is performed on.
        ;       C - Command number. Driver-dependent.
        ;       DE - 16-bit parameter, also driver-dependent.
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, BC, DE, HL
video_ioctl:
        ld a, ERR_NOT_IMPLEMENTED
        ret

        ; Write function, called everytime user application needs to output chars
        ; or pixels to the video chip.
        ; Parameters:
        ;       DE - Source buffer. Guaranteed to not cross page boundary.
        ;       BC - Size to read in bytes. Guaranteed to be equal to or smaller than 16KB.
        ;       Top of stack: 32-bit offset. MUST BE POPPED IN THIS FUNCTION.
        ;              [SP]   - Upper 16-bit of offset
        ;              [SP+2] - Lower 16-bit of offset
        ; Returns:
        ;       A  - ERR_SUCCESS if success, error code else
        ;       BC - Number of bytes written
        ; Alters:
        ;       This function can alter any register.
video_write:
        ; Clean the stack right now as HL is not used
        pop hl
        pop hl
        ; We have to map the source buffer to a reachable virtual page.
        ; Page 0 is the current code
        ; Page 1 and 2 are user's RAM
        ; Page 3 is kernel RAM
        ; Let's reserve the page 1 for mapping the video memory, the source buffer
        ; will be reachable, no matter where it is.
        call zos_sys_reserve_page_1
        ; Check return value
        or a
        ret nz
        ; Save the context returned by the previous function
        push hl
        ; FIXME: check if we are in text mode or in graphics mode
        ; At the moment always map the same 16KB containing the char and colors
        MMU_MAP_PHYS_ADDR(MMU_PAGE_1, IO_VIDEO_PHYS_ADDR_TEXT)
        push bc
        call print_buffer
        pop bc
        ; Restore the virtual page 1
        pop hl
        call zos_sys_restore_pages
        ; Return success
        xor a
        ret

        ; Read not supported yet.
        ; Pop the 32-bit value on the stack to avoid crashes.
video_read:
        pop hl
        pop hl

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
        ld a, ERR_NOT_IMPLEMENTED
        ret


        ; Map the video RAM in the second page.
        ; This is used by other drivers that want to show text or manipulate
        ; the text cursor several times, knowing that no read/write on user
        ; buffer will occur. It will let us perform a single map/unmap accross
        ; the whole process.
        ; Parameters:
        ;       None
        ; Returns:
        ;       None
        ; Alters:
        ;       A
        PUBLIC video_map_start
video_map_start:
        MMU_GET_PAGE_NUMBER(MMU_PAGE_1)
        ld (mmu_page_back), a
        ; Map VRAM in the second page (page 1)
        MMU_MAP_PHYS_ADDR(MMU_PAGE_1, IO_VIDEO_PHYS_ADDR_TEXT)
        ret

        ; Same as above, but for restoring the original page
        PUBLIC video_map_end
video_map_end:
        ld a, (mmu_page_back)
        MMU_SET_PAGE_NUMBER(MMU_PAGE_1)
        ret


        ; Show the cursor, inverted colors.
        ; The routine video_map_start must have been called
        ; beforehand.
        ; Parameters:
        ;       None
        ; Returns:
        ;       None
        ; Alters:
        ;       A, B
        PUBLIC video_show_cursor
video_show_cursor:
        ld a, (invert_color)
        ; A - Cursor color
video_show_cursor_color:
        ld hl, (cursor_pos)
        ; Offset HL to the second page by adding 0x4000
        ; And offset it to the colors attribute by adding
        ; 0x2000, overall, add 0x6000 to HL, so 0x60 to H
        ld b, a
        ld a, h
        add 0x60
        ld h, a
        ; Set the cursor color now
        ld (hl), b
        ret

        ; Hide the cursor.
        ; The routine video_map_start must have been called
        ; beforehand.
        ; Parameters:
        ;       None
        ; Returns:
        ;       None
        ; Alters:
        ;       A, B
        PUBLIC video_hide_cursor
video_hide_cursor:
        ld a, (chars_color)
        jp video_show_cursor_color

        ; Move the cursor to a near value.
        ; The routine video_map_start must have been called
        ; beforehand.
        ; Parameters:
        ;       A - signed 8-bit value representing the delta
        ; Returns:
        ;       None
        ; Alters:
        ;       A, BC, HL, DE
        PUBLIC video_move_cursor_near
video_move_cursor_near:
        ; Hide the cursor
        ld c, a
        ld a, (chars_color)
        call video_show_cursor_color
        ; Calculate cursor_pos += A
        ld b, 0
        ld a, c
        rlca
        jp nc, video_move_cursor_near_a_positive
        dec b   ; A is negative
video_move_cursor_near_a_positive:
        ld hl, (cursor_pos)
        add hl, bc
        ; Mod HL if necessary
        call video_screen_pos_mod
        ld (cursor_pos), hl
        ; Same goes for the cursor line
        ld a, (cursor_line)
        add c
        call video_line_pos_mod
        ld (cursor_line), a
        jp video_show_cursor


        ; Print a buffer from the current cursor position, but without
        ; update the cursor position at the end of the operation.
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
        PUBLIC video_print_buffer_from_cursor
video_print_buffer_from_cursor:
        ld hl, (cursor_pos)
        ; Offset HL to the second page by adding 0x4000
        set 6, h
        ; The cursor becomes the destination
        ex de, hl
        ldir
        ret

        ; Routine called everytime a V-blank interrupt occurs
        ; Must not alter A
        PUBLIC video_vblank_isr
video_vblank_isr:
        ; Add 16(ms) to the counter
        ld hl, (vblank_count)
        ld de, 16
        add hl, de
        ld (vblank_count), hl
        ret

        ;======================================================================;
        ;================= P R I V A T E   R O U T I N E S ====================;
        ;======================================================================;

        ; Routines to get the vblank count (can be used as a timer)
        ; Parameters:
        ;       None
        ; Returns:
        ;       DE - time_millis_t data type
        ;       A - ERR_SUCCESS
        ; Alters:
        ;       None
video_get_vblank:
        ld de, (vblank_count)
        xor a
        ret

        ; Routines to set the vblank count (can be used as a timer)
        ; Parameters:
        ;       DE - time_millis_t data type
        ; Returns:
        ;       A - ERR_SUCCESS
        ; Alters:
        ;       None
video_set_vblank:
        ld (vblank_count), de
        xor a
        ret

        ; Do not use vblank counter for msleep at the moment, it is less accurate than
        ; the default OS function which counts cycles.
        IF VIDEO_USE_VBLANK_MSLEEP
        ; Routine to sleep at least DE milliseconds
        ; Parameters:
        ;       DE - 16-bit duration
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       Can alter any
video_msleep:
        ; Make sure the parameter is no 0
        ld a, d
        or e
        ret z
        ; Before dividing by 16, keep E in C in order to check the remainder.
        ; Indeed, if we were asked to wait 60ms, we have to wait 4*16 = 64, and
        ; not 3*16 = 48
        ld a, e
        and 0xf
        ld b, a
        ; Divide DE by 16
        ld a, e
_video_msleep_no_carry:
        srl d
        rra
        srl d
        rra
        srl d
        rra
        srl d
        rra
        ld e, a
        ; If the remainder is not 0, increment DE by one
        ld a, b
        or a
        jp nz, _video_msleep_inc
        ; If the result is 0 (< 16ms), increment by 1
        or e
        or d
        jr nz, _video_msleep_start
_video_msleep_inc:
        inc de
_video_msleep_start:
        ; TODO: Make sure the VBlank interrupt are still enabled?
        ; Each VBlank ticks counts as 16ms, except the first one, so make sure we ignore it
        ; wait for a change on the tick count.
        ld hl, vblank_count
        ; No need to check the most-significant byte
        ld a, (hl)
_video_msleep_ignore:
        halt
        cp (hl)
        ; We can take our time here, use jr
        jr z, _video_msleep_ignore
        ; A change occured, clean the count and wait for DE ticks
        ld hl, 0
        ld (vblank_count), hl
_video_msleep_wait:
        xor a
        ld hl, (vblank_count)
        sbc hl, de
        jp c, _video_msleep_wait
        ; Success, A is already 0.
        ret
        ENDIF

        ; Parameters:
        ;       HL - Screen cursor position to perform the modulo on.
        ;            If HL is negative, it will be adjusted.
        ;       c flag - HL is negative (result of arith operation)
        ; Returns:
        ;       HL - New cursor position
        ; Alters:
        ;       A, HL, DE
video_screen_pos_mod:
        ld de, IO_VIDEO_MAX_CHAR
        bit 7, h
        jp nz, video_screen_pos_mod_negative
        ; cursor_pos is positive, check if it's too big now
        xor a   ; clear carry flag
        sbc hl, de
        ; If the result is positive or 0, nothing more the do, 
        ; HL is now between [0;IO_VIDEO_MAX_CHAR]
        ; Else, we have to add back DE before returning
        ret z
        ret nc
        ; Carry, so HL < DE, add back DE and return.
video_screen_pos_mod_negative:
        ; Cursor_pos is now negative, add IO_VIDEO_MAX_CHAR to it
        add hl, de
        ret

        ; Same as above but for the position on line
        ; Parameters:
        ;       A - Position on line
        ;       c flag - Position is negative
video_line_pos_mod:
        ld b, IO_VIDEO_X_MAX
        jp m, _video_line_pos_mod_negative
        ; Positive, check if it is too big
_video_line_pos_sub_b:
        cp b
        ret c
        sub b
        jr _video_line_pos_sub_b
_video_line_pos_mod_negative:
        add b
        ; If the result is positive, we can return
        ret p
        add b
        ret p
        jr _video_line_pos_mod_negative

        
        ; Print a NULL-terminated string
        ; Parameters:
        ;       DE - String to print
        ; Alters:
        ;       A, DE, HL

print_string:
        ld a, (de)
        or a
        ret z
        call print_char
        inc de
        jp print_string

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
        ;       DE - New address of the string (if esc seqeuences)
        ;       BC - New size of the string pointed by DE (if esc sequences)
        ; Alters:
        ;       A, BC, HL
        PUBLIC print_char
print_char:
        or a
        cp '\n'
        jp z, _print_char_newline
        cp '\r'         
        jp z, _print_char_carriage_return
        cp '\b'
        jp z, _print_char_backspace
        cp ESC_CODE
        jp z, _parse_char_escape_seq
        ; Tabulation is consider a space. Do nothing special.
        ; cp '\t'
        ; Get the cursor position
        ld hl, (cursor_pos)
        ; Offset HL to the second page!
        set 6, h
        ld (hl), a              ; Write the ASCII character to VRAM
        inc hl
        res 6, h
        ld (cursor_pos), hl     ; Save incremented position
        ; Now, we also need to increment the position-on-current-line byte
        ld hl, cursor_line
        ld a, (hl)              ; A can be reused as char has been printed
        inc a
        cp IO_VIDEO_X_MAX
        jp z, _print_char_newline_opt
        ld (hl), a      ; Save back the cursor line value
        ret
_print_char_newline_opt:
        ld (hl), 0
        ; Retrieve the cursor position in HL
        ld hl, (cursor_pos)
        ; If scroll has already started, we also need to scroll
        ; as we reached a new line
        jp _print_char_test_and_scroll
_print_char_newline:
        ; Before resetting cursor_line, let's make cursor_pos point to next line!
        ; Perform cursor_pos += IO_VIDEO_X_MAX - cursor_line
        ld a, (cursor_line)
        neg
        add IO_VIDEO_X_MAX
        ld hl, (cursor_pos)
        ; Print a new line character, it should be empty.
        ; It may seem useless, but in fact it will reset the color attributes,
        ; making the cursor not visible anymore
        set 6, h
        ld (hl), '\n'
        res 6, h
        ADD_HL_A()
        ld (cursor_pos), hl
        ; Reset cursor_line
        xor a                   ; This also reset the carry flag
        ld (cursor_line), a
        ; We have to test whether HL/cursor_pos reached the end of the screen!
_print_char_test_and_scroll:
        ; Set the cursor back to 0 in case we reached the maximum
        ld a, l
        sub IO_VIDEO_MAX_CHAR & 0xff
        jp nz, _print_char_scroll_if_needed
        ld a, h
        sub IO_VIDEO_MAX_CHAR >> 8
        jp nz, _print_char_scroll_if_needed
        ; We have to reset cursor_pos here
        ; If we reach here, A is 0, use it to reset HL.
        ld h, a
        ld l, a
        ld (cursor_pos), hl
_print_char_scroll_if_needed:
        call scroll_screen_if_needed
        jp erase_line
_print_char_carriage_return:
        ; This is similar to newline, expect that we subtract what has been reached
        ; cursor_line, instead of adding remaining chars
        ld a, (cursor_line)
        neg
        ld hl, (cursor_pos)
        ; We can add A to HL but we need to decrement H first as A is negative
        dec h
        ADD_HL_A()
        ld (cursor_pos), hl
        ; Reset cursor_line!
        xor a
        ld (cursor_line), a
        ret
_print_char_backspace:
        ld hl, (cursor_pos)      ; We will need it in all cases
        dec hl                   ; Doesn't affect the flags
        ld (cursor_pos), hl
        ld a, (cursor_line)
        dec a
        ld (cursor_line), a
        ; If dec a was positive, then no need to modify roll
        ; back anything
        ret p
        ; Else, we have to go back to the previous line because 
        ; A was 0
        ld a, IO_VIDEO_X_MAX - 1
        ld (cursor_line), a
        ; Check if HL is was 0, if that was the case, set it
        ; to the maximum - 1
        inc hl
        ld a, h
        or l
        ret nz
        ; Roll HL back
        ld hl, IO_VIDEO_MAX_CHAR - 1
        ld (cursor_pos), hl
        ret
_parse_char_escape_seq:
        ; Check if we have a character right after. We need at least
        ; 4 characters "\x1b[Ym"
        ; Flag is Z, so no carry
        ld hl, 3
        sbc hl, bc
        ; If we have not a carry, then BC is [0,3]
        ; return directly
        ret nc
        ; We won't have any problem, we can read the next chars
        inc de
        dec bc
        ld a, (de)
        ; A must be a [, else, we return
        cp '['
        ret nz
        inc de
        dec bc
        ld a, (de)
        ; Parse the next 3 chars, must be '0', '3' or 'm'
        cp '3'
        jr z, _parse_char_escape_seq_three
        cp '0'
        jr z, _parse_char_escape_seq_zero
        ; Unsupported behaviour
        ret
_parse_char_escape_seq_three:
        inc de
        dec bc
        ld a, (de)
        call is_digit
        ret c
        sub '0' + 1
        ld hl, _colors_mapping
        ADD_HL_A()
        ld h, (hl)
        ; Make sure the next character is 'm'
        inc de
        dec bc
        ld a, (de)
        cp 'm'
        ret nz
        ; Modify the color!
        ld a, h
        out (IO_VIDEO_SET_COLOR), a
        ret
_parse_char_escape_seq_zero:
        ; Make sure the next character is 'm'
        inc de
        dec bc
        ld a, (de)
        cp 'm'
        ret nz
        ; Modify the color!
        ld a, DEFAULT_CHARS_COLOR
        out (IO_VIDEO_SET_COLOR), a
        ret


        ; [0] -> Red
        ; [1] -> Green
        ; [2] -> Yellow
_colors_mapping: DEFB 0x0c, 0x0a, 0x0e, 0x00
        

        ; Scroll the screen vertically by 1 line if necessary,
        ; If the scroll index reaches the number of lines,
        ; it will be reseted to 0
        ; Parameters:
        ;       HL - New cursor_pos value 
        ; Returns:
        ;       A - New scroll value
        ; Alters:
        ;       A, HL
scroll_screen_if_needed:
        ; A scroll is needed if HL reached the scrolling point
        ld a, (scroll_at_pos)
        cp l
        ret nz
        ld a, (scroll_at_pos + 1)
        cp h
        ret nz
        ; If we arrive here, we need to scroll the screen
scroll_screen_oneline:
        ; Set the scroll_at_pos, it must be incremented by the number
        ; of chars on one line
        ld hl, (scroll_at_pos)
        ; If it reaches IO_VIDEO_MAX_CHAR, set it back to 0
        ld a, IO_VIDEO_X_MAX
        ADD_HL_A()
        ld a, l
        sub IO_VIDEO_MAX_CHAR & 0xff
        jp nz, scroll_screen_oneline_hl_no_roll
        ld a, h
        sub IO_VIDEO_MAX_CHAR >> 8
        jp nz, scroll_screen_oneline_hl_no_roll
        ; HL has reached the max, set it back to 0
        ld h, a
        ld l, a
scroll_screen_oneline_hl_no_roll:
        ld (scroll_at_pos), hl
        ; Set the hardware scroll
        ld a, (scroll_count)
        inc a
        cp IO_VIDEO_Y_MAX
        jp nz, _scroll_screen_no_roll
        xor a
_scroll_screen_no_roll:
        ld (scroll_count), a
        out (IO_VIDEO_SCROLL_Y), a
_scroll_screen_popde_ret:
        ret


        ; Set the screen scrolling to a particular value
        ; Parameters:
        ;       A - Number of lines to scroll vertically
        ; Returns:
        ;       None
        ; Alters:
        ;       A
scroll_set:
        cp IO_VIDEO_Y_MAX
        jr c, _scroll_set_correct
        sub IO_VIDEO_Y_MAX
        jr scroll_set
_scroll_set_correct:
        ld (scroll_count), a
        out (IO_VIDEO_SCROLL_Y), a
        ret

        ; Reset the vertical screen scrolling
        ; Parameters:
        ;       None
        ; Returns:
        ;       None
        ; Alters:
        ;       A
scroll_reset:
        xor a
        ld (scroll_count), a
        out (IO_VIDEO_SCROLL_Y), a
        ret


        ; Disable scrolling
        ; Parameters:
        ;       None
        ; Returns:
        ;       A - Current scrolling value
        ; Alters:
        ;       A, HL
scroll_disable:
        ld hl, screen_flags
        res SCREEN_SCROLL_ENABLED, (hl)
        ld a, (scroll_count)
        ret

        ; Erase a whole video line (writes blank character on the current line)
        ; Parameters:
        ;       None
        ; Returns:
        ;       None
        ; Alters:
        ;       A, HL
erase_line:
        push bc
        xor a
        ld hl, (cursor_pos)
        set 6, h       ; HL offset to page 2
        ld b, IO_VIDEO_X_MAX
_erase_line_loop:
        ld (hl), a
        inc hl
        djnz _erase_line_loop
        pop bc
        ret

        PUBLIC set_chars_color
set_chars_color:
        ld (chars_color), a
        ; Let video chip save this default color
        out (IO_VIDEO_SET_COLOR), a
        ret

        SECTION DRIVER_BSS
vblank_count:   DEFS 2
scroll_at_pos:  DEFS 2  ; Absolute position where a scroll is required
cursor_pos:     DEFS 2  ; 2 bytes for cursor position on the screen
cursor_line:    DEFS 1  ; 1 byte for cursor position on current line
screen_flags:   DEFS 1
scroll_count:   DEFS 1
chars_color:    DEFS 1
invert_color:   DEFS 1
mmu_page_back:  DEFS 1


        SECTION KERNEL_DRV_VECTORS
this_struct:
NEW_DRIVER_STRUCT("VID0", \
                  video_init, \
                  video_read, video_write, \
                  video_open, video_close, \
                  video_seek, video_ioctl, \
                  video_deinit)
