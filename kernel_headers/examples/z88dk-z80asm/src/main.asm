; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: CC0-1.0

    ; Include the Zeal 8-bit OS header file, containing all the syscalls macros.
    INCLUDE "zos_sys.asm"

    ; Make the code start at 0x4000, as requested by the kernel
    ORG 0x4000

    ; We can start the code here, directly, no need to create a routine, but let's keep it clean.
_start:
    ; Start by printing a message on the standard output. As we know at compile time the message, the length
    ; and the dev we want to write on, we can use S_WRITE3 macro.
    S_WRITE3(DEV_STDOUT, _message, _message_end - _message)
    ; Read from the input to get the user name. Let's use a 128-byte buffer, this should be more than enough.
    ; We could use S_READ3, but let's use READ instead as most syscalls require us to setup the parameters.
    ld h, DEV_STDIN ; Standard input dev (already opened by the kernel)
    ld de, _buffer  ; Destination buffer
    ld bc, 128      ; Buffer size
    READ()
    ; Syscalls only alters the registers that contain a return value. READ() puts error in A and the number
    ; of bytes/character in BC.
    ; Check for errors, we can use `cp ERR_SUCCESS`, but let's optimize a bit as ERR_SUCCESS is 0.
    or a
    ; Exit on error
    jr nz, _end
    ; No error, print "Hello <name>", we have to add the size of "Hello " to BC
    ld hl, _buffer - _hello_name
    add hl, bc
    ; Put the final size in BC
    ld b, h
    ld c, l
    ; Prepare the other parameters to print: H and DE.
    ; We could use S_WRITE2 here, but let's prepare the parameters manually instead.
    ld h, DEV_STDOUT
    ld de, _hello_name
    WRITE()
_end:
    ; We MUST execute EXIT() syscall at the end of any program.
    EXIT()

    ; Define a label before and after the message, so that we can get the length of the string
    ; thanks to `_message_end - _message`.
_message: DEFM "Type your name: "
_message_end:

    ; Prefix the buffer with the word "Hello ", so that we can print "Hello <name>".
_hello_name: DEFM "Hello "
    ; Buffer we will use to store the input text
_buffer: DEFS 128
