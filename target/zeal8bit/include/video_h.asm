; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    IFNDEF VIDEO_H
    DEFINE VIDEO_H

    INCLUDE "drivers/video_text_h.asm"

    MACRO LABEL_IF cond, lab
        IF cond
            PUBLIC lab
            lab:
        ENDIF
    ENDM

    ; Screen flags bit (maximum 8)
    DEFC SCREEN_SCROLL_ENABLED = 0
    DEFC SCREEN_CURSOR_VISIBLE = 1
    DEFC SCREEN_TEXT_640       = 2
    DEFC SCREEN_TEXT_320       = 3
    DEFC SCREEN_TILE_640       = 4
    DEFC SCREEN_TILE_320       = 5

    ; Flag helpers
    DEFC SCREEN_TEXT_MODE_MASK = (1 << SCREEN_TEXT_640) | (1 << SCREEN_TEXT_320)

    ; Colors used by default
    DEFC DEFAULT_CHARS_COLOR     = 0x0f ; Black background, white foreground
    DEFC DEFAULT_CHARS_COLOR_INV = 0xf0

    ; -------------------------------------------------------------------------- ;
    ;                          Hardware mapping related                          ;
    ; -------------------------------------------------------------------------- ;

    ; Physical address for the memory components.
    DEFC VID_MEM_PALETTE_OFFSET   = 0xE00

    ; It is also possible to access the I/O components via the memory bus, but for the
    ; sake of simplicity, we don't do it here.
    DEFC VID_MEM_PHYS_ADDR_START  = 0x100000
    DEFC VID_MEM_LAYER0_ADDR      = VID_MEM_PHYS_ADDR_START
    DEFC VID_MEM_PALETTE_ADDR     = VID_MEM_PHYS_ADDR_START + VID_MEM_PALETTE_OFFSET
    DEFC VID_MEM_LAYER1_ADDR      = VID_MEM_PHYS_ADDR_START + 0x1000
    DEFC VID_MEM_SPRITE_ADDR      = VID_MEM_PHYS_ADDR_START + 0x2800
    DEFC VID_MEM_FONT_ADDR        = VID_MEM_PHYS_ADDR_START + 0x3000
    DEFC VID_MEM_TILESET_ADDR     = VID_MEM_PHYS_ADDR_START + 0x10000


    ; Physical address for the I/O components.
    ; The video mapper is responsible for mapping the I/O component in the I/O bank
    ; starting at address 0xA0, up to 0xAF (16 registers)
    ; It also contains the current version of the video chip.
    DEFC VID_IO_MAPPER       = 0x80
        DEFC IO_MAPPER_REV   = VID_IO_MAPPER + 0x0
        DEFC IO_MAPPER_MIN   = VID_IO_MAPPER + 0x1
        DEFC IO_MAPPER_MAJ   = VID_IO_MAPPER + 0x2
        ; Reserved = 0x3 <-> 0xD
        DEFC IO_MAPPER_BANK  = VID_IO_MAPPER + 0xE ; I/O device bank, accessible in 0xA0
        DEFC IO_MAPPER_PHYS  = VID_IO_MAPPER + 0xF ; Physical address start of the video chip


    ; The video control and status module is non-banked, so it is available at anytime for reads
    ; and writes. It is reponsible for the screen control (mode, enable, scrolling X and Y, etc...)
    ; and the screen status (current raster position, v-blank and h-blank, etc...)
    DEFC VID_IO_CTRL_STAT = 0x90
        ; 16-bit values representing the current raster position (RO). Values latched when LSB read.
        DEFC IO_STAT_VPOS_LOW  = VID_IO_CTRL_STAT + 0x0  ; 16-bit value flushed when read
        DEFC IO_STAT_VPOS_HIGH = VID_IO_CTRL_STAT + 0x1
        DEFC IO_STAT_HPOS_LOW  = VID_IO_CTRL_STAT + 0x2  ; 16-bit value flushed when read
        DEFC IO_STAT_HPOS_HIGH = VID_IO_CTRL_STAT + 0x3
        ; 16-bit Y scrolling value for Layer0, in GFX mode (R/W). Value latched when MSB written.
        DEFC IO_CTRL_L0_SCR_Y_LOW  = VID_IO_CTRL_STAT + 0x4
        DEFC IO_CTRL_L0_SCR_Y_HIGH = VID_IO_CTRL_STAT + 0x5
        ; 16-bit X scrolling value for Layer0, in GFX mode (R/W). Value latched when MSB written.
        DEFC IO_CTRL_L0_SCR_X_LOW  = VID_IO_CTRL_STAT + 0x6
        DEFC IO_CTRL_L0_SCR_X_HIGH = VID_IO_CTRL_STAT + 0x7
        ; Similarly for Layer1 (R/W)
        DEFC IO_CTRL_L1_SCR_Y_LOW  = VID_IO_CTRL_STAT + 0x8
        DEFC IO_CTRL_L1_SCR_Y_HIGH = VID_IO_CTRL_STAT + 0x9
        DEFC IO_CTRL_L1_SCR_X_LOW  = VID_IO_CTRL_STAT + 0xa
        DEFC IO_CTRL_L1_SCR_X_HIGH = VID_IO_CTRL_STAT + 0xb
        ; Video mode register (R/W). Only takes effect after a V-blank occurs.
        DEFC IO_CTRL_VID_MODE      = VID_IO_CTRL_STAT + 0xc
        ; Video mode status
        ; Bit 0 - Set when in H-blank (RO)
        ; Bit 1 - Set when in V-blank (RO)
        ; Bit 2:6 - Reserved
        ; Bit 7 - Set to enable screen. Black screen when unset. (R/W)
        DEFC IO_CTRL_STATUS_REG    = VID_IO_CTRL_STAT + 0xd


    ; I/O modules that can be banked will appear at address 0xA0 on the I/O bus.
    DEFC VID_IO_BANKED_ADDR = 0xA0

    ; Text control module, usable in text mode (640x480 or 320x240)
    DEFC BANK_IO_TEXT_NUM = 0;

    DEFC IO_TEXT_PRINT_CHAR = VID_IO_BANKED_ADDR + 0x0
    DEFC IO_TEXT_CURS_Y     = VID_IO_BANKED_ADDR + 0x1 ; Cursor Y position (in characters count)
    DEFC IO_TEXT_CURS_X     = VID_IO_BANKED_ADDR + 0x2 ; Cursor X position (in characters count)
    DEFC IO_TEXT_SCROLL_Y   = VID_IO_BANKED_ADDR + 0x3 ; Scroll Y
    DEFC IO_TEXT_SCROLL_X   = VID_IO_BANKED_ADDR + 0x4 ; Scroll X
    DEFC IO_TEXT_COLOR      = VID_IO_BANKED_ADDR + 0x5 ; Current character color
    DEFC IO_TEXT_CURS_TIME  = VID_IO_BANKED_ADDR + 0x6 ; Blink time, in frames, for the cursor
    DEFC IO_TEXT_CURS_CHAR  = VID_IO_BANKED_ADDR + 0x7 ; Blink time, in frames, for the cursor
    DEFC IO_TEXT_CURS_COLOR = VID_IO_BANKED_ADDR + 0x8 ; Blink time, in frames, for the cursor
    ; Control register, check the flags below to see what can be achieved
    DEFC IO_TEXT_CTRL_REG   = VID_IO_BANKED_ADDR + 0x9
        DEFC IO_TEXT_SAVE_CURSOR_BIT    = 7  ; Save the current cursor position (single save only)
        DEFC IO_TEXT_RESTORE_CURSOR_BIT = 6  ; Restore the previously saved position
        DEFC IO_TEXT_AUTO_SCROLL_X_BIT  = 5
        DEFC IO_TEXT_AUTO_SCROLL_Y_BIT  = 4
        ; When the cursor is about to wrap to the next line (maximum amount of characters sent
        ; to the screen), this flag can wait for the next character to come before resetting
        ; the cursor X position to 0 and potentially scroll the whole screen.
        ; Useful to implement an eat-newline fix.
        DEFC IO_TEXT_WAIT_ON_WRAP_BIT   = 3
        ; On READ, tells if the previous PRINT_CHAR (or NEWLINE) triggered a scroll in Y
        ; On WRITE, makes the cursor go to the next line
        DEFC IO_TEXT_SCROLL_Y_OCCURRED   = 0
        DEFC IO_TEXT_CURSOR_NEXTLINE     = 0


    ; Video modes that can be given to IO_CTRL_VID_MODE register
    DEFC VID_MODE_TEXT_640     = 0;
    DEFC VID_MODE_TEXT_320     = 1;
    DEFC VID_MODE_GFX_640_8BIT = 4;
    DEFC VID_MODE_GFX_320_8BIT = 5;
    DEFC VID_MODE_GFX_640_4BIT = 6;
    DEFC VID_MODE_GFX_320_4BIT = 7;

    ; Macros for text-mode
    DEFC VID_640480_WIDTH = 640
    DEFC VID_640480_HEIGHT = 480
    DEFC VID_640480_X_MAX = 80
    DEFC VID_640480_Y_MAX = 40
    DEFC VID_640480_TOTAL = VID_640480_X_MAX * VID_640480_Y_MAX

    ENDIF
