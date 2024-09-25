; SPDX-FileCopyrightText: 2024 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "zos_sys.asm"

    SECTION TEXT

    EXTERN open_error
    EXTERN error_print
    EXTERN init_static_buffer
    EXTERN init_static_buffer_end
    DEFC STATIC_BUFFER = init_static_buffer
    DEFC STATIC_BUFFER_SIZE = init_static_buffer_end - init_static_buffer

    ; Constants related to the protocol
    DEFC METADATA_PACKET  = 0x1c
    DEFC METADATA_SIZE    = 24
    DEFC ACK_BYTE         = 0x6
    DEFC BLOCK_SIZE       = 16*1024

    ; Allows full 0x4000 size buffer. Location is fine provided init.bin size stays < 0x4000
    DEFC UART_BUFFER = 0x8000
    ; Offset of the ACK byte in the static buffer
    DEFC XFER_ACK_BYTE = METADATA_SIZE
    ; Offset of the serial descriptor in the static buffer
    DEFC XFER_SER_FD   = METADATA_SIZE + 1
    ; Offset of the file descriptor in the static buffer
    DEFC XFER_FILE_FD  = METADATA_SIZE + 2

    ; Open the UART driver
uart_open:
    ld bc, uart_driver_name
    ld h, O_RDWR
    ; BC - Path to file
    ; H - Flags
    OPEN()
    or a
    ret
uart_driver_name: DEFM "#SER0", 0


    ; Receive BC bytes from the UART and write them to the opened file.
    ; In case of an error, this routine will send the error code (ORed with 0x80) to the host.
    ; Parameters:
    ;   BC - Bytes to receive
    ; Returns:
    ;   A - 0 on success, error code else
    ; Alters:
    ;   A, BC, DE, HL
xfer_rcv_receive_and_save:
    ld a, (STATIC_BUFFER + XFER_SER_FD)
    push af
    ld h, a
    ld de, UART_BUFFER
    READ()
    or a
    jr nz, xfer_rcv_receive_and_save_error
    ; We just read a block, we can write it to the file
    ld a, (STATIC_BUFFER + XFER_FILE_FD)
    ld h, a
    ; DE and BC are already set
    WRITE()
    or a
    jr nz, xfer_rcv_receive_and_save_error
    ; Send ACK to the host
    ld a, ACK_BYTE
    jp xfer_rcv_receive_and_save_ack
    ; Send the error code to the host
xfer_rcv_receive_and_save_error:
    or 0x80
xfer_rcv_receive_and_save_ack:
    ld (de), a
    ld bc, 1
    ; Get the UART FD from the stack
    pop hl
    WRITE()
    ; No need to check the return value
    ret

    ; Check if the given string is "r" or "s"
    ; Parameters:
    ;   HL - Pointer to the string to check
    ; Returns:
    ;   A - 'r' or 's'
    ; Alters:
    ;   A, B, HL
xfer_get_op:
    push hl
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a
    ; The string address is now in HL
    ld a, (hl)
    inc hl
    ld b, 'r'
    cp b
    jr z, xfer_check_r_s_check_end
    ld b, 's'
    cp b
    jr z, xfer_check_r_s_check_end
    ; Not 'r' nor 's', fail
    pop hl
    ld a, 0xff
    ret
xfer_check_r_s_check_end:
    ; Make sure the next character is NULL
    ld a, (hl)
    pop hl
    or a
    ld a, b
    ret z
    ; Next character is not 0...
    ld a, 0xFF
    ret


    ; xfer main routine. It currently accepts two parameters: `r` for receive and the
    ; text to send on the UART.
    ; This command follows the protocol described in the script `tools/uartsnd.py` part
    ; of Zeal 8-bit OS project. It will use the serial driver registered as "SER0".
    ; A name can be provided as a parameter to override the received file name.
    ; Parameters:
    ;       HL - ARGV
    ;       BC - ARGC
    ; Returns:
    ;       A - 0 on success
    PUBLIC xfer_main
xfer_main:
    ; In all cases, we must not have more than 3 parameters
    ld a, c
    cp 4
    jr nc, xfer_usage
    ; The filename we will receive will be in STATIC_BUFFER buffer
    ld de, STATIC_BUFFER + 1
    ; Make the assumption that B is 0
    dec c  ; Do not count the command itself
    jr z, xfer_usage
    ; Make sure the next parameter is `r` for receive
    inc hl
    inc hl
    call xfer_get_op
    ; A must be 'r' or 's'
    cp 'r'
    jp z, xfer_rcv
    cp 's'
    jr z, xfer_snd
    ; Fall-through
xfer_usage:
    S_WRITE3(DEV_STDOUT, _xfer_usage_str, _xfer_usage_str_end - _xfer_usage_str)
    ret
_xfer_usage_str:
    DEFM "usage: xfer s|r [<output_file>]\n"
    DEFM "s\n    Send a file.\n"
    DEFM "r\n    Receive a file.\n"
_xfer_usage_str_end:

xfer_snd:
    ld de, 0
    ld a, ERR_NOT_IMPLEMENTED
    jp error_print

xfer_rcv:
    ; Check if we still have parameters
    dec c
    jr z, xfer_rcv_no_override
    ; The filename has to be overriden, take the given filename
    inc hl
    inc hl
    ld e, (hl)
    inc hl
    ld d, (hl)
xfer_rcv_no_override:
    ; Store the filename on the stack
    push de
    ; Open UART (Serial) driver
    call uart_open
    jp m, uart_error_pop
    ; Save the UART file descriptor is the static space
    ld (STATIC_BUFFER + XFER_SER_FD), a
    ; We need to receive the header from the host
    ld h, a
    ; Store the header block in static memory
    ld de, STATIC_BUFFER
    ld bc, METADATA_SIZE
    READ()
    or a
    ; On error, close the UART and return
    jp nz, xfer_rcv_header_error
    ; Make the assumption that we received METADATA_SIZE bytes
    ; Header was received successfully, make sure the first byte is correct
    ld a, (STATIC_BUFFER)
    cp METADATA_PACKET
    jr nz, xfer_rcv_header_corrupted
    ; Get the file to open/create in BC
    pop bc
    ld  h, O_WRONLY | O_CREAT | O_TRUNC
    OPEN()
    ; On failure return code in A
    or a
    jp m, xfer_rcv_open_dest_err
    ; Store the file descriptor in static memory
    ld (STATIC_BUFFER + XFER_FILE_FD), a
    ; Send an ACK to the host, it will give us some time before sending
    ; the next chunk of data
    ld a, ACK_BYTE
    ld de, UART_BUFFER
    ld (de), a
    ld bc, 1
    ld a, (STATIC_BUFFER + XFER_SER_FD)
    ld h, a
    WRITE()
    ; Get the number of BLOCK_SIZE blocks to receive
    ld a, (STATIC_BUFFER + 17)
    ; If there are no blocks of BLOCK_SIZE to receive, go to the end directly
    or a
    jr z, xfer_rcv_blocks_end
    ; We have blocks to proceed, store the count in B
    ld b, a
xfer_rcv_blocks_loop:
    ; Receive a whole block from UART
    push bc
    ld bc, BLOCK_SIZE
    call xfer_rcv_receive_and_save
    or a
    jr nz, xfer_rcv_receive_error
    pop bc
    djnz xfer_rcv_blocks_loop
    ; All the blocks have been processed, proceed to the remaining bytes (if any)
xfer_rcv_blocks_end:
    ; No more BLOCK_SIZE blocks to receive, continue with the remainder bytes
    ld bc, (STATIC_BUFFER + 18)
    ld a, b
    or c
    jr z, xfer_rcv_end
    call xfer_rcv_receive_and_save
    or a
    jr nz, xfer_rcv_receive_error
xfer_rcv_end:
    ; The file has been received successfully, we can close the serial driver and the file
    ld a, (STATIC_BUFFER + XFER_SER_FD)
    ld h, a
    CLOSE()
    ld a, (STATIC_BUFFER + XFER_FILE_FD)
    ld h, a
    CLOSE()
    ; Success
    xor a
    ret
    ; Jump to this branch when an error occurred when receiving the file from UART
    ; or when writing back the result to the file.
    ; We have to close the descriptors.
    ; Parameters:
    ;   A - Error received
xfer_rcv_receive_error:
    push af
    ; Close the descriptors
    call xfer_rcv_end
    pop af
    ld de, rcv_proc_error_msg
    ld bc, rcv_proc_error_msg_end - rcv_proc_error_msg
    jp error_print
rcv_proc_error_msg: DEFM "Processing error: "
rcv_proc_error_msg_end:

uart_error_pop:
    pop hl
    jp open_error

xfer_rcv_header_corrupted:
    ld a, ERR_ENTRY_CORRUPTED
xfer_rcv_header_error:
    ; Clean the stack
    pop de
    ; Close the UART driver, BC is preserved
    ld b, a
    CLOSE()
    ld a, b
    ld de, header_error_msg
    ld bc, header_error_msg_end - header_error_msg
    jp error_print
header_error_msg: DEFM "Header packet error: "
header_error_msg_end:

    ; Jump to this branch when we were unable to open the destination file
    ; Parameters:
    ;   A - Negated error code
xfer_rcv_open_dest_err:
    ; Send a non-ACK byte on the UART to prevent the host something wrong happened
    ld de, STATIC_BUFFER + XFER_ACK_BYTE    ; temporary buffer
    ; Send the error to the host, make the assumption we have less than 128 errors for now
    ld (de), a
    ld a, (STATIC_BUFFER + XFER_SER_FD)
    ld h, a
    ld bc, 1
    WRITE()
    ; Close the UART, H already contains the UART dev number
    CLOSE()
    ld a, (de)
    jp open_error
