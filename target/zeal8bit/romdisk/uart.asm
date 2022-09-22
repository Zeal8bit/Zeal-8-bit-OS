; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "syscalls_h.asm"

        SECTION TEXT

        EXTERN open_error
        EXTERN error_print
        EXTERN strlen
        EXTERN parse_int

        ; uartsnd main routine. It currently accepts a single parameter: the text to send on the UART. 
        ; It will try to open the driver registered as SER0.
        ; TODO: Implement this command to actually read data from a file.
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        PUBLIC uartsnd_main
uartsnd_main:
        dec bc  ; Do not count the command itself
        ld a, b
        or c
        ret z
        inc hl
        inc hl
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        ; HL contains the string to output on the UART
        ; Get its length and save it in BC
        push hl
        call strlen
        push bc
        call uart_open
        jp m, uart_error_pop
        ; Write to the UART
        ; DE - Buffer
        ; BC - Size
        ; H  - Descriptor
        pop bc
        pop de
        ld h, a
        WRITE()
        ; Close the driver
        CLOSE()
        ret

        ; uartrcv main routine.
        ; It currently accepts a single parameter: size to receive.
        ; It will try to open the driver registered as SER0.
        ; TODO: Implement this command to actually save data in a file.
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        PUBLIC uartrcv_main
uartrcv_main:
        dec bc  ; Do not count the command itself
        ld a, b
        or c
        ret z
        inc hl
        inc hl
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        ; Parse the length parameter
        call parse_int
        ; Check if A is 0 or not
        or a
        ; At the moment, simply return, this command is just for the sake of demonstration
        ret nz
        ; Save the buffer size
        push hl 
        call uart_open
        ; Save the size in BC
        pop bc
        jp m, open_error
        ; Read from the UART
        ; DE - Buffer
        ; BC - Size
        ; H  - Descriptor
        ld de, 0x8000
        ld h, a
        READ()
        ; TODO: Show what was actually received
        ; Close the driver
        CLOSE()
        ret

uart_open:
        ; Open the UART driver
        ; BC - Path to file
        ; H - Flags
        ld bc, uart_driver_name
        ld h, O_RDWR
        OPEN()
        or a
        ret

uart_error_pop:
        ; Clean the stack first
        pop bc
        pop hl
uart_error:
        jp open_error

uart_driver_name: DEFM "#SER0", 0

