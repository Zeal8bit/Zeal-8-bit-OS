; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "zos_sys.asm"

        SECTION TEXT

        EXTERN open_error
        EXTERN error_print
        EXTERN strlen
        EXTERN parse_int

        ; load main routine. Load a binary file form the UART at 0x4000 and jump to it.
        ; Parameters:
        ;       HL - ARGV   ; Must be the size
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        PUBLIC load_main
load_main:
        dec bc
        ld a, b
        or c
        jp z, _load_usage
        ; Parse the size given
        inc hl
        inc hl
        ld e, (hl)
        inc hl
        ld d, (hl)
        ; Put the string to parse in HL
        ex de, hl
        call parse_int
        ; Check the return value, should be 0
        or a
        jr nz, _load_usage
        ; Check that the size is not zero
        ld a, h
        or l
        jr z, _load_usage
        ; and less than or equal to 16KB
        ld b, h
        ld c, l
        dec hl
        ld a, h
        and 0xc0
        jr nz, _load_usage
        ; Success, we can load the file and jump to it
        push bc
        call uart_open
        pop bc
        jp m, open_error
        ; Before receiving data at 0x4000, we should copy the following code
        ; to a location that will not be altered. Copy it to 0xC000.
        ld de, 0xc000
        ld hl, _load_code_rom
        push bc
        ld bc, _load_code_rom_end - _load_code_rom
        ldir
        ; Jump to there to continue execution
        jp 0xc000

_load_code_rom:
        ; Read from the UART
        ; DE - Buffer
        ; BC - Size
        ; H  - Descriptor
        pop bc
        ld de, 0x4000
        ld h, a
        READ()
        ; Check if an error occurred
        or a
        jr nz, _load_read_error
        ; Close the driver
        CLOSE()
        ; Clear the stack for the user program
        ld sp, 0xffff
        ; Jump to the user program (0x4000) in case of no error
        ex de, hl
        ; We aren't supplying a parameter string in de, so set length to zero
        ld bc,0 ;
        jp (hl)
_load_read_error:
        push hl
        ld de, 0
        call error_print
        pop hl
        CLOSE()
        ret
_load_code_rom_end:


_load_usage:
        ld de, _load_usage_str
        ld bc, _load_usage_str_end - _load_usage_str
        S_WRITE1(DEV_STDOUT)
        ret
_load_usage_str:
        DEFM "usage: load <size_between_1_and_16384>\n"
_load_usage_str_end:


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

