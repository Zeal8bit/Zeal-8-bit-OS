; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "errors_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "pio_h.asm"
        INCLUDE "interrupt_h.asm"

        EXTERN video_vblank_isr
        EXTERN keyboard_interrupt_handler

        SECTION KERNEL_DRV_TEXT
        PUBLIC pio_init
pio_init:
        ; Disable interrupts for system port first
        ld a, IO_PIO_DISABLE_INT
        out (IO_PIO_SYSTEM_CTRL), a
        ; Set system port as bit-control
        ld a, IO_PIO_BITCTRL
        out (IO_PIO_SYSTEM_CTRL), a
        ; Set the proper direction for each pin
        ld a, IO_PIO_SYSTEM_DIR
        out (IO_PIO_SYSTEM_CTRL), a
        ; Set default value for all the (output) pins
        ld a, IO_PIO_SYSTEM_VAL
        out (IO_PIO_SYSTEM_DATA), a
        ; Set the CPU interrupt vector high byte
        ld a, interrupt_vector_table >> 8
        ld i, a
        ; Set interrupt vector to 2
        ld a, IO_INTERRUPT_VECT
        out (IO_PIO_SYSTEM_CTRL), a
        ; Enable the interrupts globally for the system port
        ld a, IO_PIO_ENABLE_INT
        out (IO_PIO_SYSTEM_CTRL), a
        ; Enable interrupts, for the required pins only
        ld a, IO_PIO_SYSTEM_INT_CTRL
        out (IO_PIO_SYSTEM_CTRL), a
        ; Mask must follow
        ld a, IO_PIO_SYSTEM_INT_MASK
        out (IO_PIO_SYSTEM_CTRL), a
        ld a, ERR_SUCCESS
        ret

        ; Interrupt handler, called when an interrupt occurs
        ; They shall not be the same but for the moment,
        ; let's say it is the case as only the PIO is the only driver
        ; implemented that uses the interrupts
        PUBLIC interrupt_default_handler
        PUBLIC interrupt_pio_handler
interrupt_default_handler:
interrupt_pio_handler:
        ex af, af'
        exx
        ; Check which pin triggered the interrupt, multiple pins can trigger
        ; this interrupt, so all pins shall be checked.
        in a, (IO_PIO_SYSTEM_DATA)

        IF CONFIG_TARGET_ENABLE_VIDEO
        ; Check if a V-blank interrupt occurred
        bit IO_VBLANK_PIN, a
        ; All the bits are active-low!
        call z, video_vblank_isr
        ENDIF ; CONFIG_TARGET_ENABLE_VIDEO

        bit IO_KEYBOARD_PIN, a
        call z, keyboard_interrupt_handler
        exx
        ex af, af'
        ei
        reti


        ; Disable the interrupts for both PIO ports
pio_deinit:
        ld a, IO_PIO_DISABLE_INT
        out (IO_PIO_SYSTEM_CTRL), a
        out (IO_PIO_USER_CTRL), a
        ld a, ERR_SUCCESS
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
pio_ioctl:
        ld a, ERR_NOT_IMPLEMENTED
        ret

        ; The following functions don't make sense for the PIO
pio_read:
pio_write:
        ; We need to clean the stack as it has a 32-bit value
        pop hl
        pop hl
pio_open:
pio_close:
pio_seek:
        ld a, ERR_NOT_SUPPORTED
        ret

        SECTION KERNEL_DRV_VECTORS
NEW_DRIVER_STRUCT("GPIO", \
                  pio_init, \
                  pio_read, pio_write, \
                  pio_open, pio_close, \
                  pio_seek, pio_ioctl, \
                  pio_deinit)