; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "osconfig.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "errors_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "pio_h.asm"
        INCLUDE "interrupt_h.asm"
        INCLUDE "utils_h.asm"

        EXTERN video_vblank_isr

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


        ; Register an ISR for the user port.
        ; Parameters:
        ;   HL - Address of the ISR to register
        ; Returns:
        ;   A - ERR_SUCCESS on success
        PUBLIC pio_register_user_port_isr
pio_register_user_port_isr:
        ld (pio_user_isr), hl
        xor a
        ret


        ; Routine called after all drivers have been initialized
        PUBLIC target_drivers_hook
target_drivers_hook:
        INTERRUPTS_ENABLE()
        ret

        ; Interrupt handler, called when an interrupt occurs
        ; They shall not be the same but for the moment,
        ; let's say it is the case as only the PIO is the only driver
        ; implemented that uses the interrupts
        PUBLIC interrupt_default_handler
interrupt_default_handler:
        nop
        ; Fall-through
        PUBLIC interrupt_pio_handler
interrupt_pio_handler:
        push af
        ; Check which pin triggered the interrupt, as soon as possible, multiple pins can trigger
        ; this interrupt, so all pins shall be checked.
        in a, (IO_PIO_SYSTEM_DATA)
        push de
        ld e, a
        ; Push the rest of the registers (may be on the user program stack)
        push hl
        push bc
        ; The kernel RAM may NOT BE MAPPED, we have to map it here
        MMU_GET_PAGE_NUMBER(MMU_PAGE_3)
        ; Save former page in D, we need it to restore it
        ld d, a
        MMU_MAP_KERNEL_RAM(MMU_PAGE_3)

    IF CONFIG_TARGET_ENABLE_VIDEO
        ; Check if a V-blank interrupt occurred
        bit IO_VBLANK_PIN, e
        ; All the bits are active-low!
        call z, video_vblank_isr
    ENDIF ; CONFIG_TARGET_ENABLE_VIDEO

    IF CONFIG_TARGET_KEYBOARD_PS2
        EXTERN keyboard_ps2_int_handler

        bit IO_KEYBOARD_PIN, e
        call z, keyboard_ps2_int_handler
    ENDIF

        ld a, d
        MMU_SET_PAGE_NUMBER(MMU_PAGE_3)

        pop bc
        pop hl
        pop de
        pop af
        ei
        reti


        ; Interrupt handler for the user port, this will only be used if any other driver uses the user port.
        PUBLIC interrupt_user_handler
interrupt_user_handler:
        ex af, af'
        exx

        ; Same as above
        MMU_GET_PAGE_NUMBER(MMU_PAGE_3)
        ld d, a
        MMU_MAP_KERNEL_RAM(MMU_PAGE_3)

        ; Make the assumption that an ISR has been registered
        push de
        ld hl, (pio_user_isr)
        CALL_HL()

        pop af
        MMU_SET_PAGE_NUMBER(MMU_PAGE_3)
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
pio_open:
pio_close:
pio_seek:
        ld a, ERR_NOT_SUPPORTED
        ret


        SECTION DRIVER_BSS
pio_user_isr: DEFS 2


        SECTION KERNEL_DRV_VECTORS
NEW_DRIVER_STRUCT("GPIO", \
                  pio_init, \
                  pio_read, pio_write, \
                  pio_open, pio_close, \
                  pio_seek, pio_ioctl, \
                  pio_deinit)