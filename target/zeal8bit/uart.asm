; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "osconfig.asm"
        INCLUDE "errors_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "pio_h.asm"
        INCLUDE "uart_h.asm"
        INCLUDE "interrupt_h.asm"
        INCLUDE "utils_h.asm"

        EXTERN zos_sys_remap_de_page_2

        MACRO DEFAULT_BG_COLOR _
            DEFM "16"
        ENDM


        MACRO DEFAULT_FG_COLOR _
            DEFM "15"
        ENDM

        ; Default value for other pins than UART ones
        ; This is used to output a value on the UART without sending garbage
        ; on the other lines (mainly I2C)
        DEFC PINS_DEFAULT_STATE = IO_PIO_SYSTEM_VAL & ~(1 << IO_UART_TX_PIN)

        SECTION KERNEL_DRV_TEXT
        ; PIO has been initialized before-hand, no need to perform anything here
uart_init:
        ld a, UART_BAUDRATE_DEFAULT
        ld (_uart_baudrate), a

    IF CONFIG_TARGET_STDOUT_UART
        ; Initialize the PIO because UART is the first driver. It will initialize
        ; itself once more later, but that's not an issue.
        EXTERN pio_init
        EXTERN zos_vfs_set_stdout

        call pio_init

        ; Configure the UART to convert LF to CRLF when sending bytes
        ld a, 1
        ld (_uart_convert_lf), a

        ; Initialize the escape sequence
        ld hl, ('[' << 8) | 0x1b
        ld (_uart_esc_seq), hl
        ld hl, (';' << 8) |  '8'
        ld (_uart_esc_seq + 3), hl
        ld hl, (';' << 8) |  '5'
        ld (_uart_esc_seq + 5), hl
        ld a, 'm'
        ld (_uart_esc_seq + 9), a

        ; Initialize the screen by clearing it with the default background color
        ; and setting the cursor to the top left
        ld hl, _init_sequence
        ld bc, _init_sequence_end - _init_sequence
        ld d, UART_BAUDRATE_DEFAULT
        call uart_send_bytes

        ; If the UART should be the standard output, set it at the default stdout
        ld hl, this_struct
        call zos_vfs_set_stdout

    ENDIF ; CONFIG_TARGET_STDOUT_UART

        ; Currently, the driver doesn't need to do anything special for open, close or de-init
uart_open:
uart_close:
uart_deinit:
        ; Return ERR_SUCCESS
        xor a
        ret

        ; At init, set the whole screen to black background and
        ; and foreground color to white.
_init_sequence:
            IF CONFIG_TARGET_UART_SET_MONITOR_SIZE
                DEFM 0x1b, "[8;40;80t" ; Set the host window size to 80x40 chars
            ENDIF
                DEFM 0x1b, "[48;5;"
                DEFAULT_BG_COLOR()
                DEFM "m"
                DEFM 0x1b, "[38;5;"
                DEFAULT_FG_COLOR()
                DEFM "m", 0x1b, "[H", 0x1b, "[2J"
_init_sequence_end:


        ; Perform an I/O requested by the user application.
        ; For the UART, the command number lets us set the baudrate for receiving and sending.
        ; Parameters:
        ;       B - Dev number the I/O request is performed on.
        ;       C - Command macro, any of the following macros:
        ;           * UART_SET_BAUDRATE
        ;       E - Any of the following macro:
        ;           * UART_BAUDRATE_57600
        ;           * UART_BAUDRATE_38400
        ;           * UART_BAUDRATE_19200
        ;           * UART_BAUDRATE_9600
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, BC, DE, HL
uart_ioctl:
        ; Check that the command number is correct
        ld a, c
        cp UART_SET_BAUDRATE
        jr z, _uart_ioctl_set_baud

    IF CONFIG_TARGET_STDOUT_UART
        cp CMD_GET_AREA
        jr z, _uart_ioctl_get_area
        cp CMD_SET_COLORS
        jr z, _uart_ioctl_set_colors
        cp CMD_SET_CURSOR_XY
        jr z, _uart_ioctl_set_cursor
    ENDIF ; CONFIG_TARGET_STDOUT_UART

_uart_ioctl_not_supported:
        ld a, ERR_NOT_SUPPORTED
        ret
_uart_ioctl_set_baud:
        ; Command is correct, check that the parameter is correct
        ld a, e
        cp UART_BAUDRATE_57600
        jr z, _uart_ioctl_valid
        cp UART_BAUDRATE_38400
        jr z, _uart_ioctl_valid
        cp UART_BAUDRATE_19200
        jr z, _uart_ioctl_valid
        cp UART_BAUDRATE_9600
        jr nz, _uart_ioctl_not_supported
_uart_ioctl_valid:
        ld (_uart_baudrate), a
        ; Optimization for success
        xor a
        ret

    IF CONFIG_TARGET_STDOUT_UART

_uart_ioctl_get_area:
        ; Remap DE to page 2 if it was in page 3
        call zos_sys_remap_de_page_2
        ; Let's say that the text area is 80x40
        ld hl, (80 << 8) | 40
        ex de, hl
        ld (hl), d
        inc hl
        ld (hl), e
        inc hl
        ld de, 80*40
        ld (hl), e
        inc hl
        ld (hl), d
        xor a
        ret


        ; Parameters:
        ;   D - Background color
        ;   E - Foreground color
_uart_ioctl_set_colors:
        ld a, d
        ld b, '4'
        call _uart_ioctl_set_ansi_color
        ; E is not altered by the routine above
        ld a, e
        ld b, '3'
        jp _uart_ioctl_set_ansi_color
        ; B - '4' for background, '3' for foreground
_uart_ioctl_set_ansi_color:
        ld hl, _uart_esc_seq + 2
        ld (hl), b
        ; Get the color from the table
        and 0xf
        rlca
        ld hl, _colors_table
        ADD_HL_A()
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        ld (_uart_esc_seq + 7), hl
        ; Send to sequence to the UART
        ld a, (_uart_baudrate)
        ld d, a
        ld hl, _uart_esc_seq
        ld bc, _uart_esc_seq_end - _uart_esc_seq
        jp uart_send_bytes
        ; It takes less bytes to use 2-byte strings than using BCD
_colors_table:
        DEFM "16"   ; Black
        DEFM "21"   ; Dark blue
        DEFM "28"   ; Dark green
        DEFM "12"   ; Dark cyan
        DEFM "52"   ; Dark red
        DEFM "05"   ; Dark magenta
        DEFM "94"   ; Brown
        DEFM "07"   ; Light gray
        DEFM "08"   ; Dark gray
        DEFM "04"   ; Blue
        DEFM "02"   ; Green
        DEFM "06"   ; Cyan
        DEFM "01"   ; Red
        DEFM "13"   ; Magenta
        DEFM "03"   ; Yellow
        DEFM "15"   ; White


        ; Parameters:
        ;   D - X coordinate
        ;   E - Y coordinate
        nop
        nop
_uart_ioctl_set_cursor:
        ld a, d
        cp 80
        jr c, _uart_ioctl_set_cursor_x_valid
        ld d, 79
_uart_ioctl_set_cursor_x_valid:
        ld a, e
        cp 40
        jr c, _uart_ioctl_set_cursor_y_valid
        ld e, 39
_uart_ioctl_set_cursor_y_valid:
        ; Allocate 10 bytes on the stack
        ld hl, -10
        add hl, sp
        ld sp, hl
        push hl
        ld (hl), 0x1b
        inc hl
        ld (hl), '['
        inc hl
        ; The ANSI sequence needs X and Y to actually starts at 1
        inc d
        inc e
        ; Start with Y, convert it to decimal, divide by 10
        ld a, e
        call _uart_ioctl_a_to_ascii
        ld (hl), ';'
        inc hl
        ; Same for X
        ld a, d
        call _uart_ioctl_a_to_ascii
        ld (hl), 'f'
        ; Write to the UART
        pop hl
        ld a, (_uart_baudrate)
        ld d, a
        ld bc, 8
        call uart_send_bytes
        ld hl, 10
        add hl, sp
        ld sp, hl
        xor a
        ret


        ; Convert A to ASCII and store it in HL
        ; Parameter:
        ;   A - Value to convert to ASCII
        ;   HL - Destination of ASCII value
        ; Returns:
        ;   HL - HL+2
        ; Alters:
        ;   A, BC, E, HL
_uart_ioctl_a_to_ascii:
        call _uart_ioctl_divide_a
        ; B contains quotient, A contains remainder
        add '0'
        ld c, a
        ld a, b
        add '0'
        ld (hl), a
        inc hl
        ld (hl), c
        inc hl
        ret
_uart_ioctl_divide_a:
        ld bc, 10
_uart_ioctl_divide_a_loop:
        cp c
        ret c
        ; No carry, subtract 10
        sub c
        inc b
        jr _uart_ioctl_divide_a_loop


    ENDIF ; CONFIG_TARGET_STDOUT_UART


        ; Read bytes from the UART.
        ; Parameters:
        ;       DE - Destination buffer, smaller than 16KB, not cross-boundary, guaranteed to be mapped.
        ;       BC - Size to read in bytes. Guaranteed to be equal to or smaller than 16KB.
        ;       A  - Should always be DRIVER_OP_NO_OFFSET here, no need to clean the stack.
        ; Returns:
        ;       A  - ERR_SUCCESS if success, error code else
        ;       BC - Number of bytes read.
        ; Alters:
        ;       This function can alter any register.
uart_read:
        ; Prepare the buffer to receive in HL
        ex de, hl
        ; Put the baudrate in D
        ld a, (_uart_baudrate)
        ld d, a
        jp uart_receive_bytes

uart_write:
        ; Prepare the buffer to send in HL
        ex de, hl
        ; Put the baudrate in D
        ld a, (_uart_baudrate)
        ld d, a
        jp uart_send_bytes



        ; No such thing as seek for the UART
uart_seek:
        ld a, ERR_NOT_SUPPORTED
        ret


        ; Send a sequences of bytes on the UART, with a given baudrate
        ; Parameters:
        ;   HL - Pointer to the sequence of bytes
        ;   BC - Size of the sequence
        ;   D -  Baudrate
        ; Returns:
        ;   A - ERR_SUCCESS
        ; Alters:
        ;   A, BC, HL
uart_send_bytes:
        ; Check that the length is not 0
        ld a, b
        or c
        ret z
_uart_send_next_byte:
        ld a, (hl)
        push bc
        ; Enter a critical section (disable interrupts) only when sending a byte.
        ; We must not block the interrupts for too long.
        ; TODO: Add a configuration for this?
        ENTER_CRITICAL()
        call uart_send_byte
        EXIT_CRITICAL()
        pop bc
        inc hl
        dec bc
        ld a, b
        or c
        jp nz, _uart_send_next_byte
        ; Finished sending
        ret

        ; Send a single byte on the UART
        ; Parameters:
        ;   A - Byte to send
        ;   D - Baudrate
        ; Alters:
        ;   A, BC
uart_send_byte:
        cp '\n'
        jr nz, _uart_send_byte_raw
        ; Check if we have to convert LF to CRLF
        ld a, (_uart_convert_lf)
        or a
        ld a, '\n'
        jr z, _uart_send_byte_raw
        ld a, '\r'
        call _uart_send_byte_raw
        ld a, '\n'
        ; Fall-through
_uart_send_byte_raw:
        ; Shift B to match TX pin
        ASSERT(IO_UART_TX_PIN <= 7)
        REPT IO_UART_TX_PIN
        rlca
        ENDR
        ; Byte to send in C
        ld c, a
        ; 8 bits in B
        ld b, 8
        ; Start bit, set TX pin to 0
        ld a, PINS_DEFAULT_STATE
        out (IO_PIO_SYSTEM_DATA), a
        ; The loop considers that all bits went through the "final"
        ; dec b + jp nz, which takes 14 T-states, but coming from here, we
        ; haven't been through these, so we are a bit too early, let's wait
        ; 14 T-states too.
        jp $+3
        nop
        ; For each baudrate, we have to wait N T-states in TOTAL:
        ; Baudrate 57600 => (D = 0)  => 173.6  T-states (~173 +  0 * 87)
        ; Baudrate 38400 => (D = 1)  => 260.4  T-states (~173 +  1 * 87)
        ; Baudrate 19200 => (D = 4)  => 520.8  T-states (~173 +  4 * 87)
        ; Baudrate 9600  => (D = 10) => 1041.7 T-states (~173 + 10 * 87)
        ; Wait N-X T-States inside the routine called, before sending next bit, where X is:
        ;            17 (`call` T-states)
        ;          + 4 (`ld` T-states)
        ;          + 8 (`rrc b` T-states)
        ;          + 7 (`and` T-states)
        ;          + 7 (`or` T-states)
        ;          + 12 (`out (c), a` T-states)
        ;          + 14 (dec + jp)
        ;          = 69 T-states
        ; Inside the routine, we have to wait (173 - 69) + D * 87 T-states = 104 + D * 87
uart_send_byte_next_bit:
        call wait_104_d_87_tstates
        ; Put the byte to send in A
        ld a, c
        ; Shift B to prepare next bit
        rrc c
        ; Isolate the bit to send
        and 1 << IO_UART_TX_PIN
        ; Or with the default pin value to not modify I2C
        or PINS_DEFAULT_STATE
        ; Output the bit
        out (IO_PIO_SYSTEM_DATA), a
        ; Check if we still have some bits to send. Do not use djnz,
        ; it adds complexity to the calculation, use jp which always uses 10 T-states
        dec b
        jp nz, uart_send_byte_next_bit
        ; Output the stop bit, but before, for the same reasons as the start, we have to wait the same
        ; amount of T-states that is present before th "out" from the loop: 43 T-states
        call wait_104_d_87_tstates
        ld a, IO_PIO_SYSTEM_VAL
        ; Wait 19 T-states now
        jr $+2
        ld c, 0
        ; Output the bit
        out (IO_PIO_SYSTEM_DATA), a
        ; Output some delay after the stop bit too
        call wait_104_d_87_tstates
        ret

        ; Receive a sequences of bytes on the UART.
        ; Parameters:
        ;   HL - Pointer to the sequence of bytes
        ;   BC - Size of the sequence
        ;   D - Baudrate (0: 57600, 1: 38400, 4: 19200, 10: 9600, ..., from uart_h.asm)
        ; Returns:
        ;   A - ERR_SUCCESS
        ; Alters:
        ;   A, BC, HL
uart_receive_bytes:
        ; Check that the length is not 0
        ld a, b
        or c
        ret z
        ; TODO: Implement a configurable timeout is ms, or a flag for blocking/non-blocking mode,
        ; or an any-key-pressed-aborts-transfer action.
        ; At the moment, block until we receive everything.
        ENTER_CRITICAL()
        ; Length is not 0, we can continue
_uart_receive_next_byte:
        push bc
        call uart_receive_byte
        pop bc
        ld (hl), a
        inc hl
        dec bc
        ld a, b
        or c
        jp nz, _uart_receive_next_byte
        ; Finished receiving, return
        EXIT_CRITICAL()
        ret

        ; Receive a byte on the UART with a given baudrate.
        ; Parameters:
        ;   D - Baudrate
        ; Returns:
        ;   A - Byte received
        ; Alters:
        ;   A, B, E
uart_receive_byte:
        ld e, 8
        ; A will contain the data read from PIO
        xor a
        ; B will contain the final value
        ld b, a
        ; RX pin must be high (=1), before receiving
        ; the start bit, check this state.
        ; If the line is not high, then a transfer is occurring
        ; or a problem is happening on the line
uart_receive_wait_for_idle_anybaud:
        in a, (IO_PIO_SYSTEM_DATA)
        bit IO_UART_RX_PIN, a
        jp z, uart_receive_wait_for_idle_anybaud
        ; Delay the reception
        jp $+3
        bit 0, a
uart_receive_wait_start_bit_anybaud:
        in a, (IO_PIO_SYSTEM_DATA)
        ; We can use AND and save one T-cycle, but this needs to be time accurate
        ; So let's keep BIT.
        bit IO_UART_RX_PIN, a
        jp nz, uart_receive_wait_start_bit_anybaud
        ; Delay the reception
        ld a, r     ; For timing
        ld a, r     ; For timing
        ; Add 44 T-States (for 57600 baudrate)
        ; This will let us read the bits incoming at the middle of their period
        jr $+2      ; For timing
        ld a, (hl)  ; For timing
        ld a, (hl)  ; For timing
        ; Check baudrate, if 0 (57600)
        ; Skip the wait_tstates_after_start routine
        ld a, d
        or a
        jp z, uart_receive_wait_next_bit_anybaud
        ; In case we are not in baudrate 57600,
        ; BAUDRATE * 86 - 17 (CALL)
        call wait_tstates_after_start
uart_receive_wait_next_bit_anybaud:
        ; Wait for bit 0
        ; Wait 174 T-states in total for 57600
        ; Where X = 174
        ;           - 17 (CALL T-States)
        ;           - 12 (IN b, (c) T-states)
        ;           - 8 (BIT)
        ;           - 8 (RRC B)
        ;           - 4 (DEC)
        ;           - 10 (JP)
        ;           - 18 (DEBUG/PADDING instructions)
        ;           - 10 (JP)
        ;       X = 105 - 18 = 87 T-states
        ; For any baudrate, wait 87 + baudrate * 86
        call wait_tstates_next_bit
        in a, (IO_PIO_SYSTEM_DATA)
        jp $+3      ; For timing
        bit 0, a    ; For timing
        bit IO_UART_RX_PIN, a
        jp z, uart_received_no_next_bit_anybaud
        inc b
uart_received_no_next_bit_anybaud:
        rrc b
        dec e
        jp nz, uart_receive_wait_next_bit_anybaud
        ; Set the return value in A
        ld a, b
        ret

        ; In case we are not in baudrate 57600, we have to wait about BAUDRATE * 86 - 17
        ; Parameters:
        ;   A - Baudrate
        ;   D - Baudrate
wait_tstates_after_start:
        ; For timing (50 T-states)
        ex (sp), hl
        ex (sp), hl
        bit 0, a
        nop
        ; Really needed
        dec a
        jp nz, wait_tstates_after_start
        ; 10 T-States
        ret

        ; Routine to wait 104 + D * 87 T-states
        ; A can be altered
wait_104_d_87_tstates:
        ; We need to wait 17 T-states more than in the routine below, let's wait and fall-through
        ld a, i
        bit 0, a
        ; After receiving a bit, we have to wait:
        ; 87 + baudrate * 86
        ; Parameters:
        ;   D - Baudrate
wait_tstates_next_bit:
        ld a, d
        or a
        jp z, wait_tstates_next_bit_87_tstates
wait_tstates_next_bit_loop:
        ; This loop shall be 86 T-states long
        ex (sp), hl
        ex (sp), hl
        push af
        ld a, (0)
        pop af
        ; 4 T-states
        dec a
        ; 10 T-states
        jp nz, wait_tstates_next_bit_loop
        ; Total = 2 * 19 + 11 + 13 + 10 + 4 + 10 = 86 T-states
wait_tstates_next_bit_87_tstates:
        ex (sp), hl
        ex (sp), hl
        push hl
        pop hl
        ret

        ;======================================================================;
        ;================= S T D O U T     R O U T I N E S ====================;
        ;======================================================================;

    IF CONFIG_TARGET_STDOUT_UART

        ; The following routines are used by other drivers to communicate with
        ; the standard output, check the file "stdout_h.asm" for more info about
        ; each of them (parameters, returns, registers that can be altered...)
        PUBLIC stdout_op_start
stdout_op_start:
        PUBLIC stdout_op_end
stdout_op_end:
        ; Nothing special to do here
        ret


        PUBLIC stdout_show_cursor
stdout_show_cursor:
        push hl
        push bc
        ; Send the ANSI code for showing the cursor
        ld hl, _show_cursor_seq
_stdout_send_seq:
        push de
        ld bc, _show_cursor_seq_end - _show_cursor_seq
        ld a, (_uart_baudrate)
        ld d, a
        call uart_send_bytes
        pop de
        pop bc
        pop hl
        ret
_show_cursor_seq: DEFM 0x1b, "[?25h"
_show_cursor_seq_end:


        PUBLIC stdout_hide_cursor
stdout_hide_cursor:
        push hl
        push bc
        ; Same goes for hiding the cursor, the size is the same as above
        ld hl, _hide_cursor_seq
        jr _stdout_send_seq
_hide_cursor_seq: DEFM 0x1b, "[?25l"


        PUBLIC stdout_print_char
stdout_print_char:
        ; Load baudrate in D
        ld hl, _uart_baudrate
        ld h, (hl)
        ; Save DE in HL as HL can be altered
        ex de, hl
        ; Send char in A
        ENTER_CRITICAL()
        call uart_send_byte
        EXIT_CRITICAL()
        ; Retrieve DE from HL and ret
        ex de, hl
        ret


        PUBLIC stdout_print_buffer
stdout_print_buffer:
        ; Put buffer to print in HL
        ex de, hl
        ; Baudrate in D
        ld a, (_uart_baudrate)
        ld d, a
        ; Save cursor position (DEC)
        ld e, '7'
        call _stdout_save_restore_position
        call uart_send_bytes
        ld e, '8'
        jp _stdout_save_restore_position
        ; Parameters:
        ;   D - Baudrate
        ;   E - 7 to save
        ;       8 to restore
_stdout_save_restore_position:
        push bc
        ld a, 0x1b
        ENTER_CRITICAL()
        call uart_send_byte
        ld a, e
        call uart_send_byte
        EXIT_CRITICAL()
        pop bc
        ret

    ENDIF ; CONFIG_TARGET_STDOUT_UART


        SECTION DRIVER_BSS
_uart_baudrate: DEFS 1
        ; When set to 1, LF will be convert to CRLF when sending bytes
_uart_convert_lf: DEFS 1
_uart_esc_seq: DEFS 10
_uart_esc_seq_end:

        SECTION KERNEL_DRV_VECTORS
this_struct:
NEW_DRIVER_STRUCT("SER0", \
                  uart_init, \
                  uart_read, uart_write, \
                  uart_open, uart_close, \
                  uart_seek, uart_ioctl, \
                  uart_deinit)