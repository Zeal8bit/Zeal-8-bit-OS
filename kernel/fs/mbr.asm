; SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "errors_h.asm"

    SECTION KERNEL_TEXT

    ; Search the given partition type in the MBR header. If found, the first oen will
    ; be returned. The LBA start partition will be returned, CHS is ignored.
    ; Parameters:
    ;   E  - Partition type to look for
    ;   HL - Buffer containing the MBR data (512 bytes), can be unaligned
    ; Returns:
    ;   A - ERR_SUCCESS if the partition was found
    ;       ERR_NO_SUCH_ENTRY if there is no such partition
    ;       ERR_INVALID_FILESYSTEM if the buffer is not an MBR
    ;   DEHL - LBA of the first absolute sector in the partition
    ; Alters:
    ;   A, BC, DE, HL
    PUBLIC mbr_search_partition
mbr_search_partition:
    ; Check if the buffer describes an MBR
    ; HL = HL + (512 - 2)
    inc h
    inc h
    ; Last byte should be 0xAA
    dec hl
    ld a, 0xaa
    cp (hl)
    jr nz, _mbr_search_invalid
    ; The byte before that should be 0x55
    dec hl
    ld a, 0x55
    cp (hl)
    jr nz, _mbr_search_invalid
    ; Valid MBR! Make HL point to original_HL + 0x1be + 4 (partition type field)
    ld bc, -60 ; -510 + 0x1be + 4
    add hl, bc
    ; HL points to the first partition
    ld b, 4
    ld c, 16
_mbr_search_next:
    ; Check the partition type
    ld a, (hl)
    cp e
    jr z, _mbc_search_found
    ; Not found, go to the next entry
    ; HL += C
    ld a, c
    add l
    ld l, a
    adc h
    sub l
    ld h, a
    djnz _mbr_search_next
    ; Not found
    ld a, ERR_NO_SUCH_ENTRY
    ret
_mbc_search_found:
    ; Found a matching partition type! Skip the CHS address, get the LBA address
    inc hl  ; Skip partition type
    inc hl  ; CHS 0
    inc hl  ; CHS 1
    inc hl  ; CHS 2
    ; Dereference the LBA address
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a
    ex de, hl
    xor a   ; ERR_SUCCESS
    ret
_mbr_search_invalid:
    ld a, ERR_INVALID_FILESYSTEM
    ret
