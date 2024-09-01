; SPDX-FileCopyrightText: 2023-2024 Zeal 8-bit Computer <contact@zeal8bit.com>; JasonMo <jasonmo2009@hotmail.com>;
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "zos_sys.asm"
        INCLUDE "zos_serial.asm"

        SECTION TEXT

        EXTERN open_error
        EXTERN error_print
        EXTERN strlen
        EXTERN parse_int
        EXTERN init_static_buffer
        EXTERN init_static_buffer_end
        DEFC STATIC_BUFFER = init_static_buffer
        DEFC STATIC_BUFFER_SIZE = init_static_buffer_end - init_static_buffer

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
        jr z, _uartsnd_usage

        inc hl
        inc hl
        ld c, (hl)
        inc hl
        ld b, (hl)
        ld h, O_RDONLY
        OPEN()
        or a
        jp m, open_error
        ld d, a

        call uart_open
        jp m, uart_error_pop
        ld e, a

        push de
_uartsnd_loop:
        pop de
        push de
        ; Read from source file and write to destination file, until we don't have any bytes
        S_READ3(d, STATIC_BUFFER, STATIC_BUFFER_SIZE)
        or a
        jr nz, _uart_error_close_all
        ; Check if we there are no bytes to read anymore
        ld a, b
        or c
        jr z, _uartsnd_end
        ; Get the destination descriptor back but keep it saved
        pop de
        push de
        ; BC already contains the number of bytes to write
        S_WRITE2(e, STATIC_BUFFER)
        ; In theory we should check that we wrote the same amount of bytes, but for
        ; simplicity reasons, let's only check for errors
        or a
        jp z, _uartsnd_loop
        jr _uart_error_close_all
_uartsnd_end:
        pop de
_uartsnd_close:
        ; Close the opened descriptors
        ld h, d
        CLOSE()
        ld h, e
        CLOSE()
        xor a   ; Success
        ret

_uart_error_close_all:
        pop de
        ld b, a
        call _uartsnd_close
        ld a, b
        jp error_print

_uartsnd_usage:
        S_WRITE3(DEV_STDOUT, _uartsnd_usage_str, _uartsnd_usage_str_end - _uartsnd_usage_str)
        ret
_uartsnd_usage_str:
        DEFM "usage: uartsnd <filename>\n"
_uartsnd_usage_str_end:

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
        DEFC UART_BUFFER = 0x8000 ; Allows full 0x4000 size buffer. Location is fine
                                  ; provided init.bin size stays < 0x4000
        PUBLIC uartrcv_main
uartrcv_main:
        dec bc  ; Do not count the command itself
        ; Check that size is present
        ld a, b
        or c
        jp z, _uartrcv_usage
        ; Advance past command
        inc hl
        inc hl
        ; Load address of size into DE
        ld e, (hl)
        inc hl
        ld d, (hl)
        inc hl
        ; Load the filename into BC if any, otherwise the zero arg count becomes the NULL
        dec bc
        ld a, b
        or c
        jr z, _uartrcv_main_nofile
        ld c, (hl)
        inc hl
        ld b, (hl)
_uartrcv_main_nofile:
        ex de, hl
        call parse_int
        ; Check parse (a should be zero)
        or a
        jp nz, _uartrcv_usage
        ; Add read/write size to stack frame
        push bc ; Path to the file (or NULL)
        push hl

        ; Open UART
        call uart_open
        jp m, uart_error_pop

        ; Enable the timeout
        ld h, a
        ld c, SERIAL_SET_TIMEOUT
        ld de, 1
        IOCTL()
        ; Check if an error occured
        or a
        jp nz, uart_error_pop

        ; H already contains the SERIAL dev number
        ld de, UART_BUFFER
_uartrcv_read:
        pop bc  ; Pop size to read
        push bc ; Keep it on the stack
        READ()
        ; Check read return
        or a
        jp nz, uart_error_pop
        ; Check if the size is 0 (timeout occurred before receiving any data)
        ld a, b
        or c
        jr z, _uartrcv_read
_uartrcv_done:
        ; Remove the size from the stack
        pop de

        ; Close the UART driver
        CLOSE()

        ; Prepare for write: load H with either stdout or opened file
        ; Retrieve the filename from the stack (below the top)
        ; Size in DE
        ld d, b
        ld e, c
        pop bc  ; Path in BC
        call _uartrcv_prep_output
        or a
        jp nz, open_error

        ; Successful prep, H has open device, DE has the size
        ld c, e
        ld b, d
        ld de, UART_BUFFER
        WRITE()
        ; If output was not DEV_STDOUT, close it (needed to flush file output)
        ld a, h
        cp DEV_STDOUT
        ret z
        CLOSE()

_uartrcv_prep_output:
        ; Return either stdout or opened output file, depending on whether
        ; there is a third parameter (second now that we have advanced past
        ; the command name).
        ; Parameters:
        ;   BC - Path to the file (NULL if STDOUT)
        ; Returns:
        ;   A - zero on success, open error on failure
        ;   H - descriptor on success
        ; Modifies:
        ;   BC
        ld a, b
        or c
        jr  nz, _uartrcv_open_output_file
        ; No filename, write to stdout
        ld  h, DEV_STDOUT
        ; A is already 0
        ret
_uartrcv_open_output_file:
        ; Filename in BC
        ld  h, O_WRONLY | O_CREAT | O_TRUNC
        OPEN()
        ; On failure return code in A
        or  a
        ret m
        ; Otherwise descriptor in H and 0 in A
        ld  h, a
        xor a
        ret

_uartrcv_usage:
        ld de, _uartrcv_usage_str
        ld bc, _uartrcv_usage_str_end - _uartrcv_usage_str
        S_WRITE1(DEV_STDOUT)
        ret
_uartrcv_usage_str:
        DEFM "usage: uartrcv <size_between_1_and_16384> [<output_file>]\n"
_uartrcv_usage_str_end:

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