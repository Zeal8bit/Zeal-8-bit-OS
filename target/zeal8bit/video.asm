; SPDX-FileCopyrightText: 2023-2024 Zeal 8-bit Computer <contact@zeal8bit.com>
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
        EXTERN zos_sys_remap_de_page_2
        EXTERN zos_vfs_set_stdout


        DEFC DEFAULT_VIDEO_MODE = VID_MODE_TEXT_640
        DEFC DEFAULT_CURSOR_BLINK = 30
        DEFC DEFAULT_TEXT_CTRL = 1 << IO_TEXT_AUTO_SCROLL_Y_BIT | 1 << IO_TEXT_WAIT_ON_WRAP_BIT

        MACRO MAP_TEXT_CTRL _
            xor a
            out (IO_MAPPER_BANK), a
        ENDM


    SECTION KERNEL_DRV_TEXT
    ; Initialize the video driver.
    ; This is called only once, at boot up
video_init:
    ; Set the default video mode
    ld a, DEFAULT_VIDEO_MODE
    out (IO_CTRL_VID_MODE), a

    ; Map the text controller to the banked I/O
    ASSERT (BANK_IO_TEXT_NUM == 0)
    MAP_TEXT_CTRL()

    ; Reset the cursor position, the scroll value and the color, it should already be set to default
    ; on coldboot, but maybe not on warmboot
    ; A is already 0
    out (IO_TEXT_CURS_CHAR), a
    ld a, DEFAULT_CHARS_COLOR
    out (IO_TEXT_COLOR), a
    ld a, DEFAULT_CHARS_COLOR_INV
    out (IO_TEXT_CURS_COLOR), a

    ; Clear the screen and cursor (position and scroll)
    call _video_ioctl_clear_screen

    ; Make the cursor blink every 30 frames (~500ms)
    ld a, DEFAULT_CURSOR_BLINK
    out (IO_TEXT_CURS_TIME), a

    ; Enable the screen
    ld a, 0x80
    out (IO_CTRL_STATUS_REG), a
    ; Enable auto scroll Y as well as wait-on-wrap
    ld a, DEFAULT_TEXT_CTRL
    out (IO_TEXT_CTRL_REG), a

    ; Set it at the default stdout
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

video_deinit:
    xor a   ; Success
    ret

    ; Open function, called every time a file is opened on this driver
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
    ; FIXME: reset charset, palette and attributes?
    xor a
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
    ; FIXME: Assumption we are in text mode, support GFX mode?
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
    call zos_sys_remap_de_page_2
    ; Only support 80x40 (640x480px) text mode at the moment
    ex de, hl
    ld (hl), VID_640480_X_MAX
    inc hl
    ld (hl), VID_640480_Y_MAX
    inc hl
    ld (hl), VID_640480_TOTAL & 0xff
    inc hl
    ld (hl), VID_640480_TOTAL >> 8
    ex de, hl
    xor a
    ret


    ; Return the cursor position (x,y) in registers D and E respectively
    ; Returns:
    ;   DE - Address to fill with X and Y. The buffer must be at least
    ;        16-bit big.
    ; Alters:
    ;   A, HL, DE
_video_ioctl_get_cursor_xy:
    call zos_sys_remap_de_page_2
    MAP_TEXT_CTRL()
    in a, (IO_TEXT_CURS_X)
    ld (de), a
    sub VID_640480_X_MAX
    jr nz, _video_ioctl_get_cursor_xy_no_reset
    ld (de), a
_video_ioctl_get_cursor_xy_no_reset:
    inc de
    in a, (IO_TEXT_CURS_Y)
    ld (de), a
    xor a
    ret

    ; Set the position (x,y) of the cursor. If X or Y is bigger than
    ; the maximum, they will be set to the maximum.
    ; Parameters:
    ;   D - New X position
    ;   E - New Y position
    ; Alters:
    ;   A, BC, DE, HL
_video_ioctl_set_cursor_xy:
    MAP_TEXT_CTRL()
    ; Temporarily hide the cursor
    xor a
    out (IO_TEXT_CURS_TIME), a
    ld bc, VID_640480_X_MAX << 8 | VID_640480_Y_MAX
    ; If Y is bigger than IO_VIDEO_Y_MAX, set it to IO_VIDEO_Y_MAX - 1
    ld a, e
    cp c
    jr c, _video_ioctl_set_cursor_y_valid
    ; Set A to the maximum - 1
    ld a, c
    dec a
_video_ioctl_set_cursor_y_valid:
    out (IO_TEXT_CURS_Y), a
    ld a, d
    cp b
    jr c, _video_ioctl_set_cursor_x_valid
    ld a, b
    dec a
_video_ioctl_set_cursor_x_valid:
    out (IO_TEXT_CURS_X), a
    ; Restore cursor blinking behavior
    ld a, DEFAULT_CURSOR_BLINK
    out (IO_TEXT_CURS_TIME), a
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
    MAP_TEXT_CTRL()
    ; Put both colors in a single byte 0xBF where B is background color
    ; and F is the foreground color
    ld b, 0xf
    ; E &= 0xF
    ld a, e
    and b
    ld e, a
    ; A = ((D & 0xF) << 4) | E
    ld a, d
    and b
    rlca
    rlca
    rlca
    rlca
    or e
    out (IO_TEXT_COLOR), a
    ; Save the inverted colors for the cursor
    rlca
    rlca
    rlca
    rlca
    out (IO_TEXT_CURS_COLOR), a
    ; Success
    xor a
    ret


    ; Clear the screen (with current color) and reposition the cursor.
    ; Parameters:
    ;   None
    ; Returns:
    ;   A - 0 on success
    ; Alters:
    ;   A, BC, DE, HL
_video_ioctl_clear_screen:
    MMU_GET_PAGE_NUMBER(MMU_PAGE_1)
    ld (mmu_page_back), a
    ; Map VRAM in the second page (page 1)
    MMU_MAP_PHYS_ADDR(MMU_PAGE_1, VID_MEM_LAYER0_ADDR)
    ; Clear the screen characters by writing 0 to the VRAM text part
    ld hl, 0x4000   ; second virtual page
    ld bc, VID_640480_TOTAL
    xor a
    push bc
    call _video_vram_set
    ; Clear the attributes/colors part, A is already 0
    ; That part of the RAM has an offset of 0x1000 relatively to the layer0
    ld hl, 0x4000 + 0x1000
    pop bc
    call _video_vram_set
    ; Screen has been cleared, reset the scrolling value and the cursor position
    xor a
    out (IO_TEXT_CURS_Y), a
    out (IO_TEXT_CURS_X), a
    out (IO_TEXT_SCROLL_Y), a
    out (IO_TEXT_SCROLL_X), a
    ; Restore the virtual page
    ld a, (mmu_page_back)
    MMU_SET_PAGE_NUMBER(MMU_PAGE_1)
    xor a
    ret


    ; Parameters:
    ;   HL - Address of the memory to set
    ;   BC - Size of the memory
    ;   A - Data to write to it
    ; Returns:
    ;   A - 0
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
    ; Video driver is not registered as a file system, thus A must always
    ; be 1, meaning that the stack is clean, nothing to pop.

    ; The user buffer is reachable for sure:
    ; Page 0 is the current code
    ; Page 1 and 2 are user's RAM
    ; Page 3 is kernel RAM
    ; We don't need to use page1 for VRAM since we will use I/O bus, map it and print the buffer
    MAP_TEXT_CTRL()
    jp print_buffer


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
    ; The routine video_map_start must have been called beforehand.
    ; Parameters:
    ;       None
    ; Returns:
    ;       None
    ; Alters:
    ;       A
LABEL_IF(CONFIG_TARGET_STDOUT_VIDEO, stdout_show_cursor)
video_show_cursor:
    ; Reset the cursor blinking time
    ld a, DEFAULT_CURSOR_BLINK
    out (IO_TEXT_CURS_TIME), a
    ret

    ; Hide the cursor.
    ; The routine video_map_start must have been called beforehand.
    ; Parameters:
    ;       None
    ; Returns:
    ;       None
    ; Alters:
    ;       A, HL, DE
LABEL_IF(CONFIG_TARGET_STDOUT_VIDEO, stdout_hide_cursor)
video_hide_cursor:
    ; Set the cursor blinking time to 0
    xor a
    out (IO_TEXT_CURS_TIME), a
    ret

    ; Map the video text controller in the I/O bank.
    ; This is used by other drivers that want to show text or manipulate
    ; the text cursor several times. It will let us perform a single
    ; map/unmap across the whole process.
    ; Parameters:
    ;       None
    ; Returns:
    ;       None
    ; Alters:
    ;       A
LABEL_IF(CONFIG_TARGET_STDOUT_VIDEO, stdout_op_start)
video_map_start:
    ; No need to save the previous I/O bank number for now.
    MAP_TEXT_CTRL()
    ret

    ; Same as above, but for restoring the original page
LABEL_IF(CONFIG_TARGET_STDOUT_VIDEO, stdout_op_end)
video_map_end:
    ret

IF CONFIG_TARGET_STDOUT_VIDEO
    ; Print a buffer from the current cursor position, but without
    ; updating the cursor position at the end of the operation.
    ; The characters in the buffer must all be printable characters,
    ; as they will be copied as-is on the screen.
    ; NOTE: The routine video_map_start must have been called beforehand
    ; Parameters:
    ;       DE - Buffer containing the chars to print
    ;       BC - Buffer size to render
    ; Returns:
    ;       None
    ; Alters:
    ;       A, BC, HL, DE
    PUBLIC stdout_print_buffer
stdout_print_buffer:
    ; Hide the screen cursor to avoid jumping cursor
    xor a
    out (IO_TEXT_CURS_TIME), a
    ; Save the cursor position
    ld a, DEFAULT_TEXT_CTRL | 1 << IO_TEXT_SAVE_CURSOR_BIT
    out (IO_TEXT_CTRL_REG), a
    ; Print all the characters
    call print_buffer
    ; Restore the cursor position
    ld a, DEFAULT_TEXT_CTRL | 1 << IO_TEXT_RESTORE_CURSOR_BIT
    out (IO_TEXT_CTRL_REG), a
    ; Restore the screen cursor timing
    ld a, DEFAULT_CURSOR_BLINK
    out (IO_TEXT_CURS_TIME), a
    ret

ENDIF ; CONFIG_TARGET_STDOUT_VIDEO

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
    ; A change occurred, clean the count and wait for DE ticks
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


    ; Print a buffer on the screen
    ; Parameters:
    ;   DE - Character buffer to print
    ;   BC - Size of the buffer
    ; Returns:
    ;   A - 0 (ERR_SUCCESS)
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
    ; Returns:
    ;       None
    ; Alters:
    ;       A, HL
    PUBLIC print_char
LABEL_IF(CONFIG_TARGET_STDOUT_VIDEO, stdout_print_char)
print_char:
    or a
    ret z   ; NULL-character, don't do anything
    cp '\n'
    jr z, _print_char_newline
    cp '\r'
    jr z, _print_char_carriage_return
    cp '\b'
    jr z, _print_char_backspace
    ; Tabulation is considered a space. Do nothing special.
    ; If by putting a character we end up scrolling the screen, we'll have to erase a line
_print_any_char:
    out (IO_TEXT_PRINT_CHAR), a
    ; X should be 1 if a scroll occured after outputting a character
    ld l, 1
_print_check_scroll:
    ; Check if scrolled in Y occurred
    in a, (IO_TEXT_CTRL_REG)
    ; Make the assumption that the flag is the bit 0
    ASSERT (IO_TEXT_SCROLL_Y_OCCURRED == 0)
    rrca
    ; No carry <=> No scroll Y
    ret nc
    ; Erase the current line else
    jp erase_line
_print_char_newline:
    ; Use the dedicated register to output a newline
    ld a, DEFAULT_TEXT_CTRL | 1 << IO_TEXT_CURSOR_NEXTLINE
    out (IO_TEXT_CTRL_REG), a
    ; If a scroll occurred, we need to clear the whole line, X is 0
    ld l, 0
    jp _print_check_scroll
_print_char_carriage_return:
    ; Reset cursor X to 0
    xor a
    out (IO_TEXT_CURS_X), a
    ret
_print_char_backspace:
    ; It is unlikely that X is 0 and even more unlikely that Y is too
    ; so save some time for the "best" case.
    in a, (IO_TEXT_CURS_X)
    dec a
    ; We know that the cursor X can be signed (0-127), so if the result is
    ; negative, it means that it was 0
    jp m, _print_char_backspace_x_negative
    ; X is valid, we can update it and return
    out (IO_TEXT_CURS_X), a
    ret
_print_char_backspace_x_negative:
    ; Set X to the maximum possible value
    ld a, VID_640480_X_MAX - 1
    out (IO_TEXT_CURS_X), a
    ; Y must be decremented
    in a, (IO_TEXT_CURS_Y)
    dec a
    jp p, _print_char_backspace_y_non_zero
    ; Y was 0, roll it back
    ld a, VID_640480_Y_MAX - 1
_print_char_backspace_y_non_zero:
    out (IO_TEXT_CURS_Y), a
    ; Should we manage the scroll?
    ret


    ; Erase a whole video line (writes blank character on the current line)
    ; Parameters:
    ;       L - Cursor X position
    ; Returns:
    ;       None
    ; Alters:
    ;       A, HL
erase_line:
    ld h, b ; BC must not be altered
    ; Calculate the number of characters remaining on the current line
    ld a, VID_640480_X_MAX
    sub l
    ld b, a
    ld a, ' '
_erase_line_loop:
    out (IO_TEXT_PRINT_CHAR), a
    djnz _erase_line_loop
    ; Restore B register
    ld b, h
    ; Reset X cursor position
    ld a, l
    out (IO_TEXT_CURS_X), a
    ret


    SECTION DRIVER_BSS
vblank_count:  DEFS 2
mmu_page_back: DEFS 1


    SECTION KERNEL_DRV_VECTORS
this_struct:
NEW_DRIVER_STRUCT("VID0", \
                  video_init, \
                  video_read, video_write, \
                  video_open, video_close, \
                  video_seek, video_ioctl, \
                  video_deinit)
