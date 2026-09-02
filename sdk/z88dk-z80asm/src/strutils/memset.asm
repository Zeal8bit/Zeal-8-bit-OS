; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    ; Initialize the memory pointed by HL with the byte given in E.
    ; Parameters:
    ;       HL - Memory address to initialize
    ;       BC - Size of the memory to initialize
    ;       E  - Byte to initialize the memory with
    PUBLIC memset
memset:
    ; Test that BC is not null
    ld a, b
    or c
    ret z
    ; BC is not 0, we can proceed
    push hl
    push de
    push bc
    ; Put the character to fill the memory with in A and load HL with it
    ld a, e
    ld (hl), a
    ; As we just filled the buffer with a byte, we have to decrement BC and
    ; check once again whether it is null or not
    dec bc
    ld a, b
    or c
    jp z, _memset_end
    ; DE (destination) must point to the address following HL
    ld d, h
    ld e, l
    inc de
    ; Start the copy
    ldir
 _memset_end:
    pop bc
    pop de
    pop hl
    ret
