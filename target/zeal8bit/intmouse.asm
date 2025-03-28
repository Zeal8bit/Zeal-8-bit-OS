; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

; ------------------------------------------------------------------- ;
; Driver for the Internal PS/2 Mouse, that connects to the PS/2 Port  ;
; ------------------------------------------------------------------- ;

    INCLUDE "errors_h.asm"
    INCLUDE "osconfig.asm"
    INCLUDE "drivers_h.asm"
    INCLUDE "log_h.asm"
    INCLUDE "pio_h.asm"

    DEFC MOUSE_IO_ADDRESS = 0xE8

    SECTION KERNEL_DRV_TEXT
intmouse_init:
    xor a
    ret

    PUBLIC mouse_int_handler
mouse_int_handler:
    ; Received byte in B
    in a, (MOUSE_IO_ADDRESS)
    ld b, a
@retry:
    ; Read until deassert
    in a, (IO_PIO_SYSTEM_DATA)
    bit IO_KEYBOARD_PIN, a
    jr nz, @deasserted
    in a, (MOUSE_IO_ADDRESS)
    jp @retry
@deasserted:

    ; Check if we have to reset the buffer
    ld hl, s_size
    ld a, (hl)
    cp 4
    jp c, _no_reset
    ; Reset the buffer
    xor a
    ld (hl), a
_no_reset:
    inc (hl)
    ; Store the received byte in the buffer
    ld hl, s_buffer
    add l
    ld l, a
    adc h
    sub l
    ld h, a
    ld (hl), b
    ret


intmouse_open:
intmouse_close:
intmouse_deinit:
    ; Nothing special to do in this case, return success
    ld a, ERR_SUCCESS
    ret


    ; Read function, called every time the filesystem needs data from the rom disk.
    ; Parameters:
    ;       A  - DRIVER_OP_HAS_OFFSET (0) if the stack has a 32-bit offset to pop
    ;            DRIVER_OP_NO_OFFSET  (1) if the stack is clean, nothing to pop.
    ;       DE - Destination buffer.
    ;       BC - Size to read in bytes. Guaranteed to be equal to or smaller than 16KB.
    ;
    ;       ! IF AND ONLY IF A IS 0: !
    ;       Top of stack: 32-bit offset. MUST BE POPPED IN THIS FUNCTION.
    ;              [SP]   - Upper 16-bit of offset
    ;              [SP+2] - Lower 16-bit of offset
    ; Returns:
    ;       A  - ERR_SUCCESS if success, error code else
    ;       BC - Number of bytes read.
    ; Alters:
    ;       This function can alter any register.
intmouse_read:
    or a
    jp z, intmouse_not_implemented
    ld hl, s_size
    ld a, 4
    ld b, 0
_read_wait:
    di
    cp (hl)
    jr z, _read_ready
    ei
    jr _read_wait
_read_ready:
    ; Reset the size and read the buffer
    ld (hl),  b ; [HL] = 0
    ; ASSUMPTION: s_buffer = s_size + 1
    inc hl
    ldi
    ldi
    ldi
    ldi
    ; Read the buffer and reset the size
    ei
    ; Return 4 bytes
    ld bc, 4
    ; Success
    xor a
    ret


intmouse_write:
    ; Impossible that the stack is not clean (Not registered as a disk)
intmouse_seek:
intmouse_ioctl:
intmouse_not_implemented:
    ld a, ERR_NOT_SUPPORTED
    ret



    SECTION KERNEL_BSS
s_size: DEFS 1
s_buffer: DEFS 4


    SECTION KERNEL_DRV_VECTORS
NEW_DRIVER_STRUCT("MOUS", \
                  intmouse_init, \
                  intmouse_read, intmouse_write, \
                  intmouse_open, intmouse_close, \
                  intmouse_seek, intmouse_ioctl, \
                  intmouse_deinit)