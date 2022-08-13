        INCLUDE "errors_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "pio_h.asm"
        ; INCLUDE "pub_gpio.asm"

        SECTION KERNEL_DRV_TEXT
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

        ; Open function, called everytime a file is opened on this driver
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
pio_open:
pio_read:
pio_write:
        ; Close an opened dev number.
        ; Parameter:
        ;       A  - Opened dev number getting closed
        ; Returns:
        ;       A - ERR_SUCCESS if success, error code else
        ; Alters: 
        ;       A, BC, DE, HL
pio_close:

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
pio_seek:
        ld a, ERR_NOT_IMPLEMENTED
        ret

        SECTION KERNEL_DRV_VECTORS
NEW_DRIVER_STRUCT("GPIO", \
                  pio_init, \
                  pio_read, pio_write, \
                  pio_open, pio_close, \
                  pio_seek, pio_ioctl, \
                  pio_deinit)