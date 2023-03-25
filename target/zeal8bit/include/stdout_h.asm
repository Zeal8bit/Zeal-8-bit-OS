; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

; Abstract interface for standard output that can be used by drivers in the
; kernel. As the standard output can be the UART or the video driver, other
; components can use this interface to send some directives to the output.

    IFNDEF STDOUT_H
    DEFINE STDOUT_H

    ; Prepare the stdout to receive operations from the other drivers.
    ; For example, for the video driver, this will map the VRAM.
    ; Parameters:
    ;   None
    ; Returns:
    ;   None
    ; Alters:
    ;   A
    EXTERN stdout_op_start


    ; Show the cursor on the output
    ; Parameters:
    ;   None
    ; Returns:
    ;   None
    ; Alters:
    ;   A, B
    EXTERN stdout_show_cursor


    ; Hide the cursor.
    ; Parameters:
    ;   None
    ; Returns:
    ;   None
    ; Alters:
    ;   A, B
    EXTERN stdout_hide_cursor


    ; Print a character at the cursors positions (cursor_x and cursor_y)
    ; The cursors will be updated accordingly. If the end of the screen
    ; is reached, the cursor will go back to the beginning.
    ; New line (\n) will make the cursor jump to the next line.
    ; Parameter:
    ;   A - ASCII character to output
    ; Alters:
    ;   A, BC, HL
    EXTERN stdout_print_char


    ; Print a buffer from the current cursor position, but without
    ; update the cursor position at the end of the operation.
    ; The characters in the buffer must all be printable characters,
    ; as they will be copied as-is on the screen.
    ; Parameters:
    ;   DE - Buffer containing the chars to print
    ;   BC - Buffer size to render
    ; Returns:
    ;   None
    ; Alters:
    ;   A, BC, HL, DE
    EXTERN stdout_print_buffer


    ; Needs to be called after the kernel drivers finish communicating
    ; with the stdout.
    EXTERN stdout_op_end


    ENDIF ; STDOUT_H