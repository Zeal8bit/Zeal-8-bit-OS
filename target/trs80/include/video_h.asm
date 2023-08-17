; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    IFNDEF VIDEO_H
    DEFINE VIDEO_H

    INCLUDE "drivers/video_text_h.asm"

    EXTERN zos_vfs_set_stdout

    ; Screen flags bit (maximum 8)
    DEFC SCREEN_SCROLL_ENABLED = 0
    DEFC SCREEN_CURSOR_VISIBLE = 1

    ; Virtual address of the text VRAM
    DEFC IO_VIDEO_VIRT_TEXT_VRAM = 0x3C00

    ; Macros for video chip I/O registers and memory mapping
    DEFC IO_VIDEO_SET_CHAR   = 0x80
    DEFC IO_VIDEO_SET_MODE   = 0x83
    DEFC IO_VIDEO_SCROLL_Y   = 0x85
    DEFC IO_VIDEO_SET_COLOR  = 0x86
    DEFC IO_MAP_VIDEO_MEMORY = 0x84
    DEFC MAP_VRAM            = 0x00
    DEFC MAP_SPRITE_RAM      = 0x01

    ; Video modes
    DEFC TEXT_MODE = 1

    DEFC IO_VIDEO_X_MAX = 64
    DEFC IO_VIDEO_Y_MAX = 16
    DEFC IO_VIDEO_MAX_CHAR = IO_VIDEO_X_MAX * IO_VIDEO_Y_MAX

    ENDIF
