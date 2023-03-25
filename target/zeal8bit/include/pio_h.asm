; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    IFNDEF PIO_H
    DEFINE PIO_H

    ; Chip is enabled when address high nibble is 0xD
    ; Data/Ctrl selection is bit 1
    ; Port A/B selection is bit 0
    DEFC IO_PIO_DATA_A = 0xd0
    DEFC IO_PIO_DATA_B = 0xd1
    DEFC IO_PIO_CTRL_A = 0xd2
    DEFC IO_PIO_CTRL_B = 0xd3

    ; PIO Modes
    DEFC IO_PIO_MODE0 = 0x0f
    DEFC IO_PIO_MODE1 = 0x4f
    DEFC IO_PIO_MODE2 = 0x8f
    DEFC IO_PIO_MODE3 = 0xcf
    DEFC IO_PIO_OUTPUT  = IO_PIO_MODE0
    DEFC IO_PIO_INPUT   = IO_PIO_MODE1
    DEFC IO_PIO_BIDIR   = IO_PIO_MODE2
    DEFC IO_PIO_BITCTRL = IO_PIO_MODE3

    ; PIO Interrupt control word (BITCTRL mode ONLY)
    DEFC IO_PIO_CTRLW_INT = 0x07

    ; PIO Interrupt control
    DEFC IO_PIO_DISABLE_INT = 0x03
    DEFC IO_PIO_ENABLE_INT  = 0x83

    ; Interrupt vector
    DEFC IO_INTERRUPT_VECT = 0x02

    ; PIO User port macros
    DEFC IO_PIO_USER_DATA = IO_PIO_DATA_A
    DEFC IO_PIO_USER_CTRL = IO_PIO_CTRL_A
    DEFC IO_PIO_USER_VAL  = 0xff

    ; PIO System port macros
    DEFC IO_PIO_SYSTEM_DATA = IO_PIO_DATA_B
    DEFC IO_PIO_SYSTEM_CTRL = IO_PIO_CTRL_B
    ; Default data value for the system port
    DEFC IO_PIO_SYSTEM_VAL  = 0xff

    ; Pins definition, it includes: I2C, UART, V-Blank, H-Blank, custom...
    DEFC IO_I2C_SDA_OUT_PIN = 0
    DEFC IO_I2C_SCL_OUT_PIN = 1
    DEFC IO_I2C_SDA_IN_PIN  = 2
    DEFC IO_UART_RX_PIN     = 3
    DEFC IO_UART_TX_PIN     = 4
    DEFC IO_HBLANK_PIN      = 5
    DEFC IO_VBLANK_PIN      = 6
    DEFC IO_KEYBOARD_PIN    = 7

    ; PIO system port pins direction
    ; Input pins as 1, output pins as 0
    DEFC IO_PIO_SYSTEM_DIR  = (1 << IO_KEYBOARD_PIN) | (1 << IO_VBLANK_PIN) | (1 << IO_HBLANK_PIN) | (1 << IO_UART_RX_PIN) | (1 << IO_I2C_SDA_IN_PIN)

    ; PIO System port interrupt control word
    ; Bit 7: 1 = Interrupt function enable
    ; Bit 6: 1 = AND function (0 = OR)
    ; Bit 5: 1 = Active High
    ; Bit 4: 1 = Mask follows
    ; In our case, we will:
    ; * Enable the interrupts
    ; * OR function (one of the pins going low will trigger the interrupt)
    ; * Active low signals
    ; * Provide a mask
    DEFC IO_PIO_SYSTEM_INT_CTRL = 0x90  | IO_PIO_CTRLW_INT

    ; Only H_BLANK, V_BLANK and KEYBOARD pins are monitored, but let's keep
    ; h_blank interrupts disabled, else, it would be too frequent.
    ; NOTE: 0 means monitored!
    DEFC IO_PIO_SYSTEM_INT_MASK = ~((1 << IO_KEYBOARD_PIN) | (1 << IO_VBLANK_PIN)) & 0xff
    ; DEFC IO_PIO_SYSTEM_INT_MASK = ~(1 << IO_KEYBOARD_PIN) & 0xff

    ENDIF
