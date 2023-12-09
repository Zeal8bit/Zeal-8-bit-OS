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
        ; Parameters:
        ;       HL - ARGV
        ;       BC - ARGC
        ; Returns:
        ;       A - 0 on success
        ; Modifies:
        ;       IX, DE
        PUBLIC uartrcv_main
uartrcv_main:
        ; Set up stack frame
        ld ix, 0
        add ix, sp

        dec bc  ; Do not count the command itself

        ; Check that size is present
        ld a, b
        or c
        jp z, _rcv_usage
        ; Advance past command 
        inc hl
        inc hl

        ; Load stack frame
        push hl ; remaining argv (ix-2)
        push bc ; remaining argc at (ix-4)

        ; Parse the length parameter
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        call parse_int
        ; Check parse (a should be zero)
        or a
        jp nz, _rcv_usage
        ; Add read/write size to stack frame
        push hl ; size at (ix-6)

        ; Open UART
        call uart_open
        jp m, _uart_rcv_clean_and_error

        ; Set up and do read
        ld b, (ix-5)
        ld c, (ix-6)
        ld de, 0x8000
        ld h, a
        READ()
        ; Check read return
        or a
        jp nz, _uart_rcv_clean_and_error
        ; Close the UART driver
        CLOSE() 

        ; Prepare for write: load H with either stdout or opened file
        call _uart_rcv_prep_output
        or a
        jp nz, _uart_rcv_clean_and_error

        ; Successful prep, h has open device
        ld b, (ix-5)
        ld c, (ix-6)
        ld de, 0x8000
        WRITE()
        ; If output was not DEV_STDOUT, close it (needed to flush file output)
        ld a,h
        cp DEV_STDOUT
        jr z, _uart_rcv_clean_and_return
        CLOSE()

_uart_rcv_clean_and_return:
        ld sp,ix
        ret

_uart_rcv_prep_output:
        ; Return either stdout or opened output file, depending on whether
        ; there is a third parameter (second now that we have advanced past
        ; the command name).
        ; Parameters:
        ;   (IX-2) remaining argv
        ;   (IX-4) remaining argc
        ; Returns:
        ;   A - zero on success, open error on failure
        ;   H - descriptor on success
        ; Modifies: 
        ;   BC

        ; Check if remaining argc > 1
        ld  b, (ix-3)
        ld  c, (ix-4)
        dec bc
        ld  a, b
        or  c
        jp  nz, _uart_rcv_open_output_file
        ; No filename, write to stdout
        ld  h, DEV_STDOUT 
        ret
_uart_rcv_open_output_file:
        ; Load HL with remaining argv
        ld  h, (ix-1)
        ld  l, (ix-2)
        ; Load BC with filename (argv[1])
        inc hl
        inc hl
        ld  c, (hl)
        inc hl
        ld  b, (hl)
        ld  h, O_WRONLY | O_CREAT | O_TRUNC
        OPEN()
        ; On failure return code in A
        or  a
        ret m
        ; Otherwise descriptor in H and 0 in A
        ld  h, a
        xor a
        ret

_uart_rcv_clean_and_error:
        ld sp, ix
        jp open_error

_rcv_usage:
        ld de, _rcv_usage_str
        ld bc, _rcv_usage_str_end - _rcv_usage_str
        S_WRITE1(DEV_STDOUT)
        jr _uart_rcv_clean_and_return
_rcv_usage_str:
        DEFM "usage: uartrcv <size_between_1_and_16384> [<output_file>]\n"
_rcv_usage_str_end:


; Common to all uart commands

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
        pop bc
        pop hl
        jp open_error

uart_driver_name: DEFM "#SER0", 0
