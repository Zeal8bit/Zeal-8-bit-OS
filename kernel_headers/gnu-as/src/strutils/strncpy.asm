; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .section .text

    ; Same as strcpy but if the source address is smaller than the given size,
    ; the destination buffer will be filled with NULL (\0) byte.
    ; Parameters:
    ;       HL - Source string address
    ;       DE - Destination string address
    ;       BC - Maximum number of bytes to write
    ; Alters:
    ;       A
    .globl strncpy
strncpy:
    ; Make sure that BC is not 0, else, nothing to copy
    ld a, b
    or c
    ret z
    ; Size is not 0, we can proceed
    push hl
    push de
    push bc
_strncpy_loop:
    ; Read the src byte, to check null-byte
    ld a, (hl)
    ; We cannot use ldir here as we need to check the null-byte in src
    ldi
    or a
    jp z, _strncpy_zero
    ld a, b
    or c
    jp nz, _strncpy_loop
_strncpy_end:
    pop bc
    pop de
    pop hl
    ret
_strncpy_zero:
    ; Here too, we have to test whether BC is 0 or not
    ld a, b
    or c
    jp z, _strncpy_end
    ; 0 has just been copied to dst (DE), we can reuse this null byte to fill
    ; the end of the buffer using LDIR
    ld h, d
    ld l, e
    ; Make hl point to the null-byte we just copied
    dec hl
    ; Perform the copy
    ldir
    jp _strncpy_end
