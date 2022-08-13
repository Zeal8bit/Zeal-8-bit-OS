        INCLUDE "errors_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "video_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "mmu_h.asm"

        EXTERN zos_sys_reserve_page_1
        EXTERN zos_sys_restore_pages
        EXTERN zos_vfs_set_stdout
        EXTERN is_digit

        DEFC ESC_CODE = 0x1b

        SECTION KERNEL_DRV_TEXT
        ; Initialize the video driver.
        ; This is called only once, at bootup
video_init:
        ld a, TEXT_MODE_640
        out (IO_VIDEO_SET_MODE), a
        xor a
        out (IO_VIDEO_SCROLL_Y), a
        ld a, DEFAULT_CHARS_COLOR
        out (IO_VIDEO_SET_COLOR), a
        ; FIXME: Once the real FPGA (and the simulator) support 24-bit physical
        ;        addresses, remove this unecessary memory mapper.
        ;ld a, MAP_VRAM
        ;out (IO_MAP_VIDEO_MEMORY), a
        ; Set it at the default stodut
        ld hl, this_struct
        call zos_vfs_set_stdout
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
        ; FIXME: Once the real FPGA (and the simulator) support 24-bit physical
        ;        addresses, remove this unecessary memory mapper.
        ; ld a, MAP_VRAM
        ; out (IO_MAP_VIDEO_MEMORY), a
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
        ;       BC - Number of bytes written.
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
        call print_buffer
        ; Restore the virtual page 1
        pop hl
        call zos_sys_restore_pages
        ; Return success
        xor a
        ret

video_read:
        ; Read not supported yet.
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

        ;======================================================================;
        ;================= P R I V A T E   R O U T I N E S ====================;
        ;======================================================================;

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
        ;       None
        ; Alters:
        ;       A, BC, HL
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
        ; Here, no need to update the cursor_pos
        ld (hl), 0
        ; If scroll has already started, we also need to scroll
        ; as we reached a new line
        jp _print_char_scroll_if_needed
_print_char_newline:
        ; Before resetting cursor_line, let's make cursor_pos point to next line!
        ; Perform cursor_pos += IO_VIDEO_X_MAX - cursor_line
        ld a, (cursor_line)
        neg
        add IO_VIDEO_X_MAX
        ld hl, (cursor_pos)
        ADD_HL_A()
        ld (cursor_pos), hl
        ; Reset cursor_line
        xor a                   ; This also reset the carry flag
        ld (cursor_line), a
        ; We have to test whether HL/cursor_pos reached the end of the screen!
        ld a, l
        sub IO_VIDEO_MAX_CHAR & 0xff
        jp nz, _print_char_scroll_if_needed
        ld a, h
        sub IO_VIDEO_MAX_CHAR >> 8
        jp nz, _print_char_scroll_if_needed
        ; We have to reset cursor_pos here
        ;ld hl, IO_VIDEO_MAX_CHAR - IO_VIDEO_X_MAX
        ; If we reach here, A is 0, use it to reset HL.
        ld h, a
        ld l, a
        ld (cursor_pos), hl
        ld hl, screen_flags
        set SCREEN_SCROLL_ENABLED, (hl)
_print_char_scroll_if_needed:
        ld hl, screen_flags
        bit SCREEN_SCROLL_ENABLED, (hl)
        call nz, scroll_screen
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
        ld a, (cursor_line)
        dec a
        ret m ; Result negative, cursor_line was 0
        ld (cursor_line), a
        ld hl, cursor_pos
        dec (hl)
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
_colors_mapping: DEFB 0x0c, 0x0a, 0x0e
        

        ; Scroll the screen vertically by 1 line
        ; If the scroll index reaches the number of lines,
        ; it will be reseted to 0
        ; Parameters:
        ;       None
        ; Returns:
        ;       A - New scroll value
        ; Alters:
        ;       A
scroll_screen:
        ld a, (scroll_count)
        inc a
        cp IO_VIDEO_Y_MAX
        jp nz, _scroll_screen_no_roll
        xor a
_scroll_screen_no_roll:
        ld (scroll_count), a
        out (IO_VIDEO_SCROLL_Y), a
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
        ;       A, HL, B
erase_line:
        xor a
        ld hl, (cursor_pos)
        ld b, IO_VIDEO_X_MAX
_erase_line_loop:
        ld (hl), a
        inc hl
        djnz _erase_line_loop
        ret

        PUBLIC set_chars_color
set_chars_color:
        ld (chars_color), a
        ; Let video chip save this default color
        out (IO_VIDEO_SET_COLOR), a
        ret

        SECTION DRIVER_BSS
cursor_pos:     DEFS 2  ; 2 bytes for cursor position on the screen
cursor_line:    DEFS 1  ; 1 byte for cursor position on current line
screen_flags:   DEFS 1
scroll_count:   DEFS 1
chars_color:    DEFS 1
invert_color:   DEFS 1


        SECTION KERNEL_DRV_VECTORS
this_struct:
NEW_DRIVER_STRUCT("VID0", \
                  video_init, \
                  video_read, video_write, \
                  video_open, video_close, \
                  video_seek, video_ioctl, \
                  video_deinit)
