; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: CC0-1.0

    ; Include the Zeal 8-bit OS header files: the syscalls and the keyboard
    ; interface (keyboard modes and key codes).
    .include "zos_sys.asm"
    .include "zos_keyboard.asm"

    ; The .text section will be linked at address `0x4000`
    .text

    .global _start
_start:
    ; Put the keyboard in RAW mode: every key press and key release is sent to
    ; the user program on read. Values >= 0x80 mark special keys or key release
    ; events, they are ignored in this example.
    ld h, DEV_STDIN
    ld c, KB_CMD_SET_MODE
    ld de, KB_MODE_RAW
    IOCTL()
    ; Check for errors
    or a
    jr nz, _end

    ; Print a small prompt
    S_WRITE3 DEV_STDOUT, _prompt, _prompt_end - _prompt

_loop:
    ; Read a single byte from the keyboard, this is blocking until a key is
    ; pressed (in raw mode).
    ld h, DEV_STDIN
    ld de, _key
    ld bc, 1
    READ()
    ; Check for errors
    or a
    jr nz, _end

    ; Ignore special keys and key release events
    ld a, (_key)
    cp 0x80
    jr nc, _loop

    ; Enter (0x0a) stops the program
    cp KB_KEY_ENTER
    jr z, _end

    ; Echo the pressed character back on the standard output
    ld h, DEV_STDOUT
    ld de, _key
    ld bc, 1
    WRITE()
    jr _loop

_end:
    ; Exit code is stored in H, 0 means success
    ld h, 0
    EXIT()

    .size _start, . - _start

    .data
_prompt: .ascii "Raw keyboard mode: press a key to echo it, Enter to quit.\n"
_prompt_end:
_key: .space 1
