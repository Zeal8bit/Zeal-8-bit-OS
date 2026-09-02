; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    SECTION TEXT

    ; Concatenate two strings by writing at most BC bytes, including NULL byte.
    ; This function will add NULL-terminating byte.
    ; Parameters:
    ;   HL - Destination string
    ;   DE - Source to copy at the end of HL
    ;   BC - Maximum bytes to copy (including \0)
    ; Returns:
    ;   A - 0 if success, 1 if result is too long
    ;   DE - Address of the former NULL-byte of HL
    ; Alters:
    ;   A
    PUBLIC strncat
strncat:
    push hl
    push bc
    xor a
    cpir
    ; Test is BC is 0!
    ld a, b
    or c
    ld a, 1 ; In case of an error
    jp z, _strncat_src_null
    ; HL points to the address past the NULL-byte.
    ; Similarly, BC has counted the NULL-byte
    dec hl
    push hl     ; Former NULL-byte
    ; We should now copy bytes until BC is 0 or [DE] is 0
    ex de, hl
_strncat_copy:
    xor a
    or (hl)
    ldi
    jp z, _strncat_pop_de
    ; Check if BC is 0
    ld a, b
    or c
    jp nz, _strncat_copy
    ; BC is 0, terminate dst and return
    ld (de), a
    ; We have to return A > 0 so increment
    inc a
_strncat_pop_de:
    pop de
_strncat_src_null:
    ; We've met a null pointer in src, which was copied successfully
    ; A is already 0, we can return
    pop bc
    pop hl
    ret

