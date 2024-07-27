; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "zos_sys.asm"
    INCLUDE "zos_video.asm"
    INCLUDE "zos_keyboard.asm"

    DEFC BYTES_PER_LINE = 16
    DEFC FILE_BUFFER = init_static_buffer
    ; Must be a multiple of BYTES_PER_LINE
    DEFC FILE_BUFFER_SIZE = init_static_buffer_end - (BYTES_PER_LINE * 5)  - init_static_buffer
    DEFC LINE_BUFFER = init_static_buffer_end - (BYTES_PER_LINE * 5)
    DEFC LINE_BUFFER_SIZE = (BYTES_PER_LINE * 5)


    EXTERN is_print
    EXTERN byte_to_ascii
    EXTERN error_print
    EXTERN init_static_buffer
    EXTERN init_static_buffer_end


    SECTION TEXT

    ; Parameters:
    ;       HL - ARGV
    ;       BC - ARGC
    ; Returns:
    ;       A - 0 on success
    PUBLIC hexdump_main
hexdump_main:
    ; Check that there are exactly two parameters
    dec c
    dec c
    jp nz, _hexdump_usage
    ; Skip first parameter (command name)
    inc hl
    inc hl
    ; Dereference the parameter
    ld c, (hl)
    inc hl
    ld b, (hl)
    ; Open the file
    ld h, O_RDONLY
    OPEN()
    ; Error if A is negative
    or a
    jp m, _hexdump_error_neg
    ld (file_dev), a
    ; Reset the file offset
    ld hl, 0
    ld (file_offset), hl
_hexdump_main_loop:
    ; Read from the file
    ld de, FILE_BUFFER
    ld bc, FILE_BUFFER_SIZE
    ld a, (file_dev)
    ld h, a
    READ()
    or a
    jr nz, _hexdump_error
    ; If we read 0 from the file, exit with a new line
    ld a, b
    or c
    jr z, _hexdump_main_end
_hexdump_buffer_loop:
    ; Write the minimum between HL and BC characters
    push bc ; Store the remaining bytes
    ld hl, BYTES_PER_LINE
    call _hex_dump_min_hl_bc
    push de
    push bc ; Number of bytes to write
    call hexdump_print_bc_chars
    pop bc
    ; Update DE with the next characters to print
    pop hl
    add hl, bc
    ex de, hl
    ; Update the remaining bytes and store it in BC
    pop hl
    or a
    sbc hl, bc
    ld b, h
    ld c, l
    ; Check if we still have some bytes in the current buffer
    ld a, b
    or c
    jp nz, _hexdump_buffer_loop
    jp _hexdump_main_loop
_hexdump_main_end:
    ; Close the file
    ld a, (file_dev)
    ld h, a
    CLOSE()
    ret

_hexdump_error_neg:
    neg
    ; No file to close, we haven't opened it yet
    jr _hexdump_error_no_close
_hexdump_error:
    ; Save the error code and close the opened file
    push af
    call _hexdump_main_end
    pop af
_hexdump_error_no_close:
    ld de, 0
    jp error_print

    ; Calculate the minimum between HL and BC and put the result in BC
    ; Parameters:
    ;   HL - 16-bit value
    ;   BC - 16-bit value
    ; Returns:
    ;   BC - Minimum between HL and BC
    ; Alters:
    ;   HL, BC
_hex_dump_min_hl_bc:
    or a    ; Clear carry flag
    sbc hl, bc
    ret nc
    ; HL was the minimum, restore it and store it in BC
    add hl, bc
    ld b, h
    ld c, l
    ret


    ; Print/dump the given buffer as string of hex values
    ; Parameters:
    ;   DE - Buffer containing the bytes to print
    ;   (B)C - Number of bytes to dump
    ; Returns:
    ;   -
    ; Alters:
    ;   A, BC, DE, HL
hexdump_print_bc_chars:
    ; Save original DE and BC for the moment
    push de
    push bc
    ; Clear the buffer
    ld hl, LINE_BUFFER
    ld de, LINE_BUFFER + 1
    ld (hl), ' '
    ld bc, LINE_BUFFER_SIZE - 2
    ldir
    pop bc
    ; Store a newline at the end of the buffer
    ld a, '\n'
    ld (de), a
    ; Fill the buffer with the actual line to print
    ; Start by getting the current offset in the file, convert it to ASCII
    ld hl, (file_offset)
    ld a, h
    call byte_to_ascii
    push de
    ld a, l
    call byte_to_ascii
    ; Update the offset since we are at it
    ld a, c ; BC is in fact an 8-bit value for sure, keep it in A
    add hl, bc
    ld (file_offset), hl
    ; Update the line buffer
    pop bc  ; high-byte of the address
    ld hl, LINE_BUFFER
    ld (hl), b
    inc hl
    ld (hl), c
    inc hl
    ld (hl), d
    inc hl
    ld (hl), e
    inc hl
    ld (hl), ':'
    inc hl
    ; Keep a space after ':''
    inc hl
    ; Iterate over all the bytes we have to dump
    ld b, a
    ; Use C as the number of bytes written
    ld c, 0
    pop de  ; Get back the original buffer
hexdump_print_chars_loop:
    ld a, (de)
    push de
    call byte_to_ascii
    ld (hl), d
    inc hl
    ld (hl), e
    inc hl
    inc hl
    pop de
    ld a, (de)
    call buffer_insert_ascii
    inc de
    inc c
    djnz hexdump_print_chars_loop
    ; Print the buffer
    S_WRITE3(DEV_STDOUT, LINE_BUFFER, LINE_BUFFER_SIZE)
    ret


    ; Populate the ASCII character part of the line (end)
    ; Parameters:
    ;   A - Character to print
    ;   C - Index of the character
    ; Alters:
    ;   A
buffer_insert_ascii:
    push hl
    ld hl, LINE_BUFFER + 57
    push af
    ; HL += C
    ld a, c
    add l
    ld l, a
    adc h
    sub l
    ld h, a
    ; If the character is not printable, use '.' instead
    pop af
    call is_print
    jr nc, _buffer_insert_ascii_valid
    ld a, '.'
_buffer_insert_ascii_valid:
    ld (hl), a
    pop hl
    ret


_hexdump_usage:
    S_WRITE3(DEV_STDOUT, _hexdump_usage_str, _hexdump_usage_str_end - _hexdump_usage_str)
    ret
_hexdump_usage_str:
    DEFM "usage: hexdump <file>\n", 0
_hexdump_usage_str_end:


file_dev:     DEFS 1
file_offset:  DEFW 0
