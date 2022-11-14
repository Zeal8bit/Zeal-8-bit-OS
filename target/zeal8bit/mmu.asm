; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "mmu_h.asm"
    INCLUDE "errors_h.asm"

    SECTION KERNEL_DRV_TEXT

    ; Size of the bitmask in bytes
    DEFC MMU_BITMASK_SIZE = MMU_RAM_PHYS_PAGES / 8

    ; Opcode for RES
    DEFC OPCODE_RES = 0x86

    ; Same, for SET
    DEFC OPCODE_SET = 0xc6

    ; Allocate a page that will be used for the user program.
    ; This routine is public as it will be called by the kernel.
    ; The returned index can be an abstract context, the kernel will pass it to
    ; MMU_SET_PAGE_NUMBER macro when it will want to map it.
    ; Parameters:
    ;   None
    ; Returns:
    ;   A - ERR_SUCCESS on success, ERR_NO_MORE_MEMORY when all the pages are allocated
    ;   B - Number of the newly allocated page (which can be passed to MMU_SET_PAGE_NUMBER)
    ; Alters:
    ;   A, HL, BC
    PUBLIC  mmu_alloc_page
mmu_alloc_page:
    xor a   ; If bitmask is 0, then all pages are allocated
    ; B will contain the index of the byte containing the free page, set it to 0
    ld b, a
    ld hl, mmu_bitmap
    or (hl)
    jr nz, _mmu_alloc_found
    REPT MMU_BITMASK_SIZE - 1
    inc b
    inc hl
    or (hl)
    jr nz, _mmu_alloc_found
    ENDR
    ; Didn't find any free page, no more memory
    ld a, ERR_NO_MORE_MEMORY
    ret
_mmu_alloc_found:
    ; HL points to the bitmap containing at least 1 free page, A contains (HL)
    ; B contains the index of the value (A) in the array. Multiply by 8 to get
    ; the number of bits skipped.
    rlc b
    rlc b
    rlc b
    ; Rotate A until we find the bit set to 1
_mmu_alloc_next_bit:
    rrca
    jr c, _mmu_bit_found
    inc b   ; next bit
    jr _mmu_alloc_next_bit
_mmu_bit_found:
    ; Bit found! B contains the page number, relative to the RAM's first page,
    ; make it absolute. Mark the page as allocated in the bitmap.
    ld c, OPCODE_RES
    call mmu_mark_page_fast
    ; B is not altered by the routine we just called
    ld a, MMU_RAM_PHYS_START_IDX
    add b
    ld b, a
    ; Optimization for A = ERR_SUCCESS
    xor a
    ret


    ; Free a page previously allocated with mmu_free_page.
    ; Parameters:
    ;   A - Allocated page to free.
    ; Returns:
    ;   A - ERR_SUCCESS on success, ERR_NO_MORE_MEMORY when all the pages are allocated
    ; Alters:
    ;   A, HL, BC
    PUBLIC  mmu_free_page
mmu_free_page:
    sub MMU_RAM_PHYS_START_IDX
    ; If result has a carry, the parameter was invalid
    jp nc, mmu_mark_page_free
    ld a, ERR_INVALID_PARAMETER
    ret

    ; ====== Private routines ====== ;
    ; The routines below are marked PUBLIC because they are used in macros in `mmu_h.asm`.
    ; But they are private to the target implementation, they won't be explicitly called
    ; by the kernel.

    ; Initialize the mmu RAM code, used as self-modifying code
    ; Doesn't alter A.
    PUBLIC mmu_init_ram_code
mmu_init_ram_code:
    ld hl, mmu_ram_code
    ld (hl), 0xcb
    inc hl
    inc hl
    ld (hl), 0xc9 ; ret
    ret

    ; Make the RAM page A as allocated. This will reset its bit in the bitmap.
    ; Parameters:
    ;   A - RAM page index/number to mark as allocated (Between 0 and MMU_BITMASK_SIZE - 1)
    ; Returns:
    ;   A - ERR_SUCCESS on success, error code else
    ; Alters:
    ;   A, BC, HL
    PUBLIC mmu_mark_page_allocated
    PUBLIC mmu_mark_page_free
mmu_mark_page_allocated:
    ld c, OPCODE_RES
    jr mmu_mark_page
mmu_mark_page_free:
    ld c, OPCODE_SET
    ; Fall-through
    ; Mark a given RAM page as allocated or free.
    ; The operation is specified in register D.
    ; Parameters:
    ;   A - RAM page index/number to change state
    ;   C - 0x86 = Reset bit (allocated)
    ;       0xC6 = Set bit (freed) 
mmu_mark_page:
    ld b, a
    ; Divide A by 8
    rrca
    rrca
    rrca
    and 3   ; Result between 0 and 3
    ; mmu_bitmap is aligned on 4
    ld hl, mmu_bitmap
    add l
    ld l, a
    ; If HL is already set to the mask to clear/set,
    ; B contains the bit to clear and C is set to the operation to perform,
    ; call this subroutine!
    ; Returns:
    ;   A - ERR_SUCCESS
    ; Alters:
    ;   A
mmu_mark_page_fast:
    ; Get the bit to clear in B
    ld a, b
    and 7
    ; We need to multiple by 8
    rlca
    rlca
    rlca
    ; We have to clear/set bit B of (hl). One possibility would be to generate a mask
    ; out of the bit number, but that takes a lot of CPU cycles.
    ; The fastest solution is self-modifying code. The opcode to use is in register C.
    ; The other opcodes have been initialized already.
    or c
    ld (mmu_ram_code_bit), a
    ; TODO: Check that the bit has the opposite value, i.e. free when allocating it 
    ;       and allocated when freeing it
    ; Tail-call, prepare the A = ERR_SUCCESS
    xor a
    jp mmu_ram_code


    SECTION NOINIT_DATA
    ; Bitmap used to store the free and allocated pages.
    ; Each bit represents a 16KB physical page, 1 means free, 0 means allocated.
    ; Bit 0 of byte 0 represents RAM page 0.
    PUBLIC mmu_bitmap
    ALIGN 4
mmu_bitmap: DEFS MMU_BITMASK_SIZE

    ; 2-instruction code in RAM:
    ; res bit, (hl)
    ; ret
    ; This will be used to clear a bit of the bitmap.
mmu_ram_code: DEFS 1
mmu_ram_code_bit: DEFS 1
mmu_ram_code_ret: DEFS 1