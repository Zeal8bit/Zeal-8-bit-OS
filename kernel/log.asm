; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "errors_h.asm"
        INCLUDE "osconfig.asm"
        INCLUDE "log_h.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "drivers/video_text_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "strutils_h.asm"

        EXTERN zos_vfs_write
        EXTERN zos_boilerplate

        SECTION KERNEL_TEXT

        ; The log component will let any other module output texts on the standard output.
        ; If the standard output has not been set up yet, the messages will be copied
        ; to an internal buffer (if configured to do so).
        ; As soon as the standard output is set, the buffer will be flushed to the driver,
        ; and the buffer won't be used anymore.

        PUBLIC zos_log_init
zos_log_init:
        ret


        ; Routine called as soon as stdout is set in the VFS
        ; In our case, we will print the system boilerplate
        ; if this is the first time the stdout is set.
        ; In other words, print the boilerplate if we are booting.
        ; Parameters:
        ;       HL - STDOUT driver
        PUBLIC zos_log_stdout_ready
zos_log_stdout_ready:
        ; We are going to optimize this a bit. Instead of calling vfs function
        ; to write to the stdout, we will directly communicate with the driver.
        ; Get driver's write routine in HL
        ld d, h
        ld e, l
        GET_DRIVER_WRITE()
        ld (_log_write_fun), hl
        ; Also save ioctl function, for switching colors
        ex de, hl
        GET_DRIVER_IOCTL()
        ld (_log_ioctl_fun), hl
        ; Check if we have already printed the boilerplate. If not, print it now.
        ld hl, _log_plate_printed
        ld a, (hl)
        or a
        ret nz
        inc (hl)
        xor a   ; No prefix to print
        ld hl, zos_boilerplate
        jp zos_log_message


        ; Use IOCTL to the video/text driver to switch colors
        ; Parameters:
        ;   A - Foreground color
        ; Alters:
        ;   A
_zos_log_set_color:
        push hl
        push de
        ; Background and foreground in D and E respectively
        ld d, TEXT_COLOR_BLACK
        ld e, a
        ld hl, (_log_ioctl_fun)
        ld a, h
        or l
        jr z, _zos_log_set_color_pop
        push bc
        ; STDOUT dev in B (0), set color command in C
        ld bc, CMD_SET_COLORS
        CALL_HL()
        pop bc
_zos_log_set_color_pop:
        pop de
        pop hl
        ret

        ; Log an error message starting with (E) and in red color if supported.
        ; Parameters:
        ;       HL - Message to print
        PUBLIC zos_log_error
zos_log_error:
        ld a, TEXT_COLOR_RED
        call _zos_log_set_color
        ld a, 'E'
        jr zos_log_message_current_color


        ; Same as above with prefix (W) and color yellow.
        ; Parameters:
        ;       HL - Message to print
        PUBLIC zos_log_warning
zos_log_warning:
        ld a, TEXT_COLOR_YELLOW
        call _zos_log_set_color
        ld a, 'W'
        jr zos_log_message_current_color


        ; Same as above but in green
        ; Parameters:
        ;       HL - Message to print
        PUBLIC zos_log_info
zos_log_info:
        ld a, TEXT_COLOR_GREEN
        call _zos_log_set_color
        ld a, 'I'
        jr zos_log_message_current_color


        ; Log a message in the log buffer or STDOUT
        ; Parameters:
        ;       A - Letter to put in between the () prefix.
        ;           No prefix if A is 0.
        ;       HL - Message to print
        ; Returns:
        ;       None
        ; Alters:
        ;       A
        PUBLIC zos_log_message
zos_log_message:
        push af
        ; Use white a the default color
        ld a, TEXT_COLOR_WHITE
        call _zos_log_set_color
        pop af
zos_log_message_current_color:
        ; Do not alter parameters
        push bc
        push de
        push hl
        ; Check if we need to print the prefix
        or a
        jp z, _zos_log_no_prefix
        ; Set the letter to put in the ( )
        ld de, _log_prefix + 1
        ld (de), a
        dec de
        ld bc, _log_prefix_end - _log_prefix
        call _zos_log_call_write
        ; Get the original HL to print, without altering the stack
        pop hl
        push hl
_zos_log_no_prefix:
        ; Calculate the length of the string in HL
        call strlen
        ex de, hl
        call _zos_log_call_write
        pop hl
        pop de
        pop bc
        ret


        ; Private routine to call the driver's write function
        ; Parameters:
        ;       DE - Buffer to print
        ;       BC - Size of the buffer
        ; Alters:
        ;       A, BC, DE, HL
_zos_log_call_write:
        ; Load the function address
        ld hl, (_log_write_fun)
        ; Check if the function is 0!
        ld a, h
        or l
        ret z
        ; Specify that we don't have any offset on the stack
        ld a, DRIVER_OP_NO_OFFSET
        jp (hl)


        SECTION KERNEL_DATA
_log_prefix:        DEFM "( ) "
_log_prefix_end:


        SECTION KERNEL_BSS
_log_plate_printed: DEFS 1
_log_write_fun:     DEFS 2
_log_ioctl_fun:     DEFS 2

        IF CONFIG_LOG_BUFFER_SIZE > 0
_log_index:  DEFS 2
_log_buffer: DEFS CONFIG_LOG_BUFFER_SIZE
        ENDIF