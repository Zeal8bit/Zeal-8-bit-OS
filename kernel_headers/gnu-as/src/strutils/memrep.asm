; SPDX-FileCopyrightText: 2026 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    .section .text

    ; Replace a byte by another in an array.
    ; Parameters:
    ;   A - Old byte to replace
    ;   L - New byte
    ;   DE - Memory address
    ;   BC - Memory length
    ; Returns:
    ;   BC - 0
    ;   HL - Memory address + memory length (DE + BC)
    ; Alters:
    ;   A, HL, BC, DE
    .globl memrep
memrep:
    ex de, hl
_memrep_loop:
    ; New byte in E
    cpir
    ; If z flag is not set, BC is 0
    ret nz
    ; Replace old byte with the new one
    dec hl
    ld (hl), e
    inc hl
    ; Still need to check if BC is 0
    ld d, a
    ld a, b
    or c
    ld a, d
    jp nz, _memrep_loop
    ret

