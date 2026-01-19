; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .section .text

    .extern strlen
    .extern memsep

    ; Look for the delimiter A in the string pointed by HL
    ; Once it finds it, the token is replace by \0
    ; Parameters:
    ;       HL - Address of the string
    ;       A  - Delimiter
    ; Returns:
    ;       HL - Original string address
    ;       DE - Address of the next string (address of the token found +1)
    ;       A - 0 if the delimiter was found, non-null value else
    ; Alters:
    ;       DE, A
    .globl strsep
strsep:
    push bc
    call strlen
    call memsep
    pop bc
    ret
