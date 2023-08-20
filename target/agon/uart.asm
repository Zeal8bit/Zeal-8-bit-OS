; SPDX-FileCopyrightText: 2023 Shawn Sijnstra <shawn@sijnstra.com>
;
; SPDX-License-Identifier: Apache-2.0
UART0_PORT              EQU     0C0h             ; UART0
                                
UART0_REG_RBR:          EQU     UART0_PORT+0    ; Receive buffer
UART0_REG_THR:          EQU     UART0_PORT+0    ; Transmitter holding
UART0_REG_DLL:          EQU     UART0_PORT+0    ; Divisor latch low
UART0_REG_IER:          EQU     UART0_PORT+1    ; Interrupt enable
UART0_REG_DLH:          EQU     UART0_PORT+1    ; Divisor latch high
UART0_REG_IIR:          EQU     UART0_PORT+2    ; Interrupt identification
UART0_REG_FCT:          EQU     UART0_PORT+2;   ; Flow control
UART0_REG_LCR:          EQU     UART0_PORT+3    ; Line control
UART0_REG_MCR:          EQU     UART0_PORT+4    ; Modem control
UART0_REG_LSR:          EQU     UART0_PORT+5    ; Line status
UART0_REG_MSR:          EQU     UART0_PORT+6    ; Modem status
UART0_REG_SCR:          EQU     UART0_PORT+7    ; Scratch

TX_WAIT                 EQU     32768   ;16384           ; Count before a TX times out

UART_LSR_ERR            EQU     080h             ; Error
UART_LSR_ETX            EQU     040h             ; Transmit empty
UART_LSR_ETH            EQU     020h             ; Transmit holding register empty
UART_LSR_RDY            EQU     001h             ; Data ready

cr:                     EQU     0Dh
lf:                     EQU     0Ah

; Get a GPIO register
; Parameters:
; - REG: Register to test
; - VAL: Bit(s) to test
;       
GET_GPIO:               MACRO   REG, VAL
                        IN0     A,(REG)
                        TST     A, VAL
                        ENDM

        INCLUDE "osconfig.asm"
        INCLUDE "errors_h.asm"
        INCLUDE "drivers_h.asm"
        INCLUDE "video_h.asm"
        INCLUDE "keyboard_h.asm"
        INCLUDE "interrupt_h.asm"
        INCLUDE "utils_h.asm"

        MACRO DEFAULT_BG_COLOR _
            DEFM "16"
        ENDM


        MACRO DEFAULT_FG_COLOR _
            DEFM "15"
        ENDM

        EXTERN zos_vfs_set_stdout
        EXTERN zos_vfs_set_stdin

        SECTION KERNEL_DRV_TEXT
        ; PIO has been initialized before-hand, no need to perform anything here
uart_init:
        ; Assuming the UART0 is already set up by MOS and sync'd to VDP.

        ; Configure the UART to convert LF to CRLF when sending bytes
        ld a, 1
        ld (_uart_convert_lf), a

        ; Initialize the screen by clearing it with the default background color
        ; and setting the cursor to the top left
        ld hl, _init_sequence
        ld bc, _init_sequence_end - _init_sequence

        ; TODO: send sequence HL (size BC)
        call uart_write_hl_raw

        ; If the UART should be the standard output, set it at the default stdout
        ld hl, this_struct
        call zos_vfs_set_stdout
        ; If the UART should be the standard input, set it at the default stdin
        ld hl, this_struct
        call zos_vfs_set_stdin
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
                DEFM 0x17, 0, 255       ; 23,0,255 is set terminal mode

                DEFM 0x1b, "["
                DEFAULT_BG_COLOR()
                DEFM "m"
                DEFM 0x1b, "["
                DEFAULT_FG_COLOR()
                DEFM "m", 0x1b, "[H", 0x1b, "[2J"

_init_sequence_end:

        ; Perform an I/O requested by the user application.
        ; For the UART, the command number lets us set the baudrate for receiving and sending.
        ; Parameters:
        ;       B - Dev number the I/O request is performed on
        ;           Ignored on Agon Light
        ;       C - Command macro, any of the following macros:
        ;           * KB_CMD_SET_MODE
        ;           * CMD_SET_COLORS
        ;           * CMD_SET_COLORS
        ; not suppoted:
        ;           * UART_SET_BAUDRATE
        ; Returns:
        ;       A - ERR_SUCCESS on success, error code else
        ; Alters:
        ;       A, BC, DE, HL
uart_ioctl:
;ignoring device but leaving in stub as comments - assuming always UART0 so that STDIO also works.
;    dec b                    
;    jr z, uart_in_ioctl
    ; Else, UART as output
;    ld a, ERR_NOT_IMPLEMENTED
;    ret

uart_in_ioctl:
    ; The only valid STDIN command at the moment is KB_CMD_SET_MODE
    ld a, c
    cp KB_CMD_SET_MODE
    jr z, uart_mode_set
        cp CMD_SET_COLORS
        jr z, _uart_ioctl_set_colors
        cp CMD_CLEAR_SCREEN
        jp z, _uart_clear_screen
    jr  uart_in_ioctl_invalid
    ; Save the mode in a static variable
uart_mode_set:
    ld a, e  ; E contains the mode, must be smaller than KB_MODE_COUNT, let's assum it is for simplicity
    ld (uart_stdin_mode), a
    ; Success
    xor a 
    ret
uart_in_ioctl_invalid:
    ld a, ERR_INVALID_PARAMETER
    ret

_uart_ioctl_not_supported:
_uart_ioctl_set_baud:
        ld a, ERR_NOT_SUPPORTED
        ret

_uart_ioctl_get_area:
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
        ld      b,d
        ld      d,0
        ld      a,01bh       ;Set up ANSI esc sequence <ESC>[
        call    UART0_serial_TX
        ld      a,'['
        call    UART0_serial_TX
        ld      a,e
        cp      8            ;check bright or dim colour code
        ld      a,'3'
        jr      c,_fg_set_color_is_dim
        ld      a,'9'
_fg_set_color_is_dim:
        call    UART0_serial_TX
        ld      a,e             ;foreground colour
        and     7
        ld      e,a
        ld      hl,_colors_table
        add     hl,de           ;calculate offset
        ld      a,(hl)
        call    UART0_serial_TX
        ld      a,';'
        call    UART0_serial_TX
        ld      a,b
        cp      8            ;check bright or dim colour code
        ld      a,'4'
        jr      c,_bg_set_color_is_dim
        ld      a,'1'
        call    UART0_serial_TX
        ld      a,'0'
_bg_set_color_is_dim:
        call    UART0_serial_TX
        ld      a,b             ;background colour
        and     7
        ld      e,a
        ld      hl,_colors_table
        add     hl,de
        ld      a,(hl)
        call    UART0_serial_TX
        ld      a,'m'           ;ANSI code for setting colour
        jp      UART0_serial_TX                

; Table below maps the ZealOS colour palette to ANSI colours.
_colors_table:
        DEFM "0"   ; Dark gray (Black)
        DEFM "4"   ; Blue
        DEFM "2"   ; Green
        DEFM "6"   ; Cyan
        DEFM "1"   ; Red
        DEFM "5"   ; Magenta
        DEFM "3"   ; Yellow
        DEFM "7"   ; White


        ; Parameters:
        ;   D - X coordinate
        ;   E - Y coordinate
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
        ld bc, 8
        call uart_write_hl
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


; Clear the screen and reposition the cursor at the top left
_uart_clear_screen:
        ld hl, _uart_clear_str
        ld bc, _uart_clear_str_end - _uart_clear_str
        jp uart_write_hl_raw
_uart_clear_str:
        DEFM 0x1b, "[H", 0x1b, "[J"
_uart_clear_str_end:

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
        ; Check that the length is not 0
        ld a, b
        or c
        ret z
        ; Prepare the buffer to receive in HL
        ex de, hl
        ld      de,0
         ENTER_CRITICAL()
        ; Length is not 0, we can continue
_uart_receive_next_byte:
;        push bc
        call UART0_serial_RX
        jr      nc,_uart_receive_next_byte
;        pop bc
        or      a
        jr      z,_uart_receive_next_byte
        cp      7fh
        jr      z,_uart_read_BS
        cp      8
        jr      z,_uart_read_BS        
        ld (hl), a
        inc hl
        dec bc
        inc de
        cp      '\n'
        jr      z,uart_read_ok
        cp      '\r'
        jr      z,uart_read_ok
        call    UART0_serial_TX ;echo as we are in cooked mode here
        ld a, b
        or c
        jp nz, _uart_receive_next_byte
        ; Finished receiving, return
        EXIT_CRITICAL()
uart_read_ok:
        ld      a,'\n'
        dec     hl
        ld      (hl),a
        inc     hl
        call    UART0_serial_TX
        ld      a,'\r'
        call    UART0_serial_TX      
        ld      b,d
        ld      c,e
        xor     a
        ret
_uart_read_BS:
        ld      a,d
        or      e
        jr      z,_uart_receive_next_byte
        dec     hl
        dec     de
        inc     bc
        ld      a,8
        call    UART0_serial_TX
        ld      a,' '
        call    UART0_serial_TX
        ld      a,8
        call    UART0_serial_TX
        jr      _uart_receive_next_byte

uart_write:
        ex      de,hl
        ; Internal write
uart_write_hl:
        ld a, b
        or c
        ret z
        ld a, (hl)
        push bc
        ; Enter a critical section (disable interrupts) only when sending a byte.
        ; We must not block the interrupts for too long.
        ENTER_CRITICAL()
        call uart_send_byte
        EXIT_CRITICAL()
        pop bc
        inc hl
        dec bc
        jr      uart_write_hl
        ret

uart_write_raw:
        ; TODO
;        ld a, ERR_NOT_IMPLEMENTED
 ;       ret
        ex      de,hl
        ; Internal write
uart_write_hl_raw:
        ld a, b
        or c
        ret z
        ld a, (hl)
        push bc
        ; Enter a critical section (disable interrupts) only when sending a byte.
        ; We must not block the interrupts for too long.
        ; TODO: Add a configuration for this?
        ENTER_CRITICAL()
        call _uart_send_byte_raw
        EXIT_CRITICAL()
        pop bc
        inc hl
        dec bc
        jr      uart_write_hl
        ret

        ; No such thing as seek for the UART
uart_seek:
        ld a, ERR_NOT_SUPPORTED
        ret

; Read a character from UART0
; Returns:
; - A: Data read
; - F: C if character read
; - F: NC if no character read
;
UART0_serial_RX:
        IN0             A,(UART0_REG_LSR)       ; Get the line status register
        AND             UART_LSR_RDY            ; Check for characters in buffer
        RET             Z                       ; Just ret (with carry clear) if no characters
        IN0             A,(UART0_REG_RBR)       ; Read the character from the UART receive buffer
        SCF                                     ; Set the carry flag
        RET



; Write a character to UART0
; Parameters:
; - A: Data to write
; Returns:
; - F: C if written
; - F: NC if timed out
; TODO: check if cooked vs raw?
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
UART0_serial_TX:        PUSH            BC                      ; Stack BC
                        PUSH            AF                      ; Stack AF
; Check whether we're clear to send (UART0 only)
;

UART0_wait_CTS:         GET_GPIO        PD_DR, 8                ; Check Port D, bit 3 (CTS)
                        JR              NZ, UART0_wait_CTS

                        LD              BC,TX_WAIT              ; Set CB to the transmit timeout
UART0_serial_TX1:
                      IN0             A,(UART0_REG_LSR)       ; Get the line status register
                        AND             UART_LSR_ETX            ; Check for TX empty
                        JR              NZ, UART0_serial_TX2    ; If set, then TX is empty, goto transmit
                        DEC             BC
                        LD              A, B
                        OR              C
                        JR              NZ, UART0_serial_TX1
                        POP             AF                      ; We've timed out at this point so
                        POP             BC                      ; Restore the stack
                        OR              A                       ; Clear the carry flag and preserve A
                        RET     
UART0_serial_TX2:       POP             AF                      ; Good to send at this point, so
                        OUT0            (UART0_REG_THR),A       ; Write the character to the UART transmit buffer
                        POP             BC                      ; Restore BC
                        SCF                                     ; Set the carry flag
                        RET 

        ;======================================================================;
        ;================= S T D O U T     R O U T I N E S ====================;
        ;======================================================================;

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
        call uart_write_hl
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
        ; TODO
        ld a, ERR_NOT_IMPLEMENTED
        ret


        PUBLIC stdout_print_buffer
stdout_print_buffer:
        call _stdout_save_restore_position
        ; TODO, write the characters
        jp _stdout_save_restore_position

        ; Parameters:
        ;   D - Baudrate
        ;   E - 7 to save
        ;       8 to restore
_stdout_save_restore_position:
        push bc
        ld a, 0x1b
        ; TODO: implement send byte
        ; call uart_send_byte
        ld a, e
        ; call uart_send_byte
        pop bc
        ret


        SECTION DRIVER_BSS
uart_stdin_mode: defs   1
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