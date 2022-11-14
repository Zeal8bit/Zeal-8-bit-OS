; SPDX-FileCopyrightText: 2022 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

    INCLUDE "romdisk_info_h.asm"
    INCLUDE "osconfig.asm"

    IFNDEF MMU_H
    DEFINE MMU_H

    ; Virtual page size is 16KB (so we have 4 pages)
    DEFC MMU_VIRT_PAGES_SIZE = 0x4000

    ; Size of the RAM in bytes
    DEFC MMU_RAM_SIZE = 512 * 1024

    ; RAM physical address
    DEFC MMU_RAM_PHYS_ADDR = 0x80000 ; 512KB
    ; Index of the first RAM page
    DEFC MMU_RAM_PHYS_START_IDX = MMU_RAM_PHYS_ADDR / MMU_VIRT_PAGES_SIZE
    ; Number of 16KB pages for the RAM: 512KB/16KB
    DEFC MMU_RAM_PHYS_PAGES = MMU_RAM_SIZE / MMU_VIRT_PAGES_SIZE
    ; RAM page index of kernel RAM
    DEFC MMU_KERNEL_RAM_PAGE_INDEX = (CONFIG_KERNEL_RAM_PHYS_ADDRESS >> 14) - MMU_RAM_PHYS_START_IDX

    ; MMU pages configuration I/O address
    DEFC MMU_PAGE_0 = 0xF0
    DEFC MMU_PAGE_1 = 0xF1
    DEFC MMU_PAGE_2 = 0xF2
    DEFC MMU_PAGE_3 = 0xF3

    ; Virtual Pages Addresses
    DEFC MMU_PAGE0_VIRT_ADDR = 0x0000
    DEFC MMU_PAGE1_VIRT_ADDR = 0x4000
    DEFC MMU_PAGE2_VIRT_ADDR = 0x8000
    DEFC MMU_PAGE3_VIRT_ADDR = 0xC000

    ; Routines implemented in `mmu.asm` source file
    EXTERN mmu_init_ram_code
    EXTERN mmu_alloc_page
    EXTERN mmu_free_page
    EXTERN mmu_mark_page_allocated
    EXTERN mmu_bitmap

    ; Macro used to map a physical address to a virtual page. Both must be defined at compile time.
    MACRO MMU_MAP_PHYS_ADDR page, address
        ASSERT(address < 0x400000) ; Max 4MB of physical memory
        ld a, address >> 14  ; Virtual address are 16 - 2 = 14 bits wide
        out (page), a
    ENDM

    MACRO MMU_SET_PAGE_NUMBER page
        ASSERT(page >= MMU_PAGE_0 && page <= MMU_PAGE_3)
        out (page), a
    ENDM

    ; Get the MMU configuration for a page declared at compile time.
    MACRO MMU_GET_PAGE_NUMBER page
        ASSERT(page >= MMU_PAGE_0 && page <= MMU_PAGE_3)
        ld a, page << 6 & 0xff
        in a, (page)
    ENDM

    ; Get the MMU configuration for a page declared at runtime, in A
    ; Page must be between 0 and 3.
    MACRO MMU_GET_PAGE_NUMBER_A _
        rrca
        rrca    ; Put 0-3 in top bits
        in a, (MMU_PAGE_0) ; when reading, only 0xF_ matters
    ENDM

    ; Get the page index out of a virtual address.
    ; For example:
    ; 0x0000-0x3fff returns 0 (page 0)
    ; 0x4000-0x7fff returns 1 (page 1)
    ; 0x8000-0xbfff returns 2 (page 2)
    ; 0xc000-0xffff returns 3 (page 3)
    ; Parameters:
    ;   HIGH,LOW - 16-bit virtual address
    ;   Where HIGH and LOW are two registers
    ; Returns:
    ;   A - Page index
    ; Alters:
    ;   A
    MACRO MMU_GET_PAGE_INDEX_FROM_VIRT_ADDRESS HIGH, LOW
        ld a, HIGH
        rlca
        rlca
        and 3
    ENDM

    ; Macro used to map the kernel RAM into the specified virtual page 
    MACRO MMU_MAP_KERNEL_RAM page
        ASSERT(page >= MMU_PAGE_0 && page <= MMU_PAGE_3)
        ; For some reasons, z88dk doesn't allow us to call another macro is a macro...
        ; Copy the content of MMU_MAP_PHYS_ADDR here. When it will be supported,
        ; the following should be used:
        ; MMU_MAP_PHYS_ADDR(page, CONFIG_KERNEL_RAM_PHYS_ADDRESS)
        ld a, CONFIG_KERNEL_RAM_PHYS_ADDRESS >> 14
        out (page), a
    ENDM

    MACRO MMU_ALLOC_PAGE _
        call mmu_alloc_page
    ENDM

    ; Free a previously allocated page
    ; Must not alter HL, DE
    MACRO MMU_FREE_PAGE page
        ld a, page
        call mmu_free_page
    ENDM

    MACRO MMU_INIT _
        LOCAL _kernel_not_in_ram
        LOCAL _shift
        ; Map Kernel RAM now and initialize the allocation bitmap
        ; z88dk doesn't support using a macro in a macro, when it will be supported,
        ; Replace the following with: MMU_MAP_KERNEL_RAM(MMU_PAGE_3)
        ld a, CONFIG_KERNEL_RAM_PHYS_ADDRESS >> 14
        out (MMU_PAGE_3), a
        ; Clear the allocated bitmap
        ld hl, 0xFFFF
        ; At the moment, we know we have only 4 bytes, no need to make a loop
        ASSERT(MMU_RAM_PHYS_PAGES == 32)
        ld (mmu_bitmap), hl
        ld (mmu_bitmap + 2), hl
        ; In theory, the stack is not ready, let's take some advance and set it
        ;  in order ot be able to call a function
        ld sp, CONFIG_KERNEL_STACK_ADDR
        call mmu_init_ram_code
        ; Mark kernel RAM page as allocated (page number in A, subtract RAM start index)
        ld a, MMU_KERNEL_RAM_PAGE_INDEX
        call mmu_mark_page_allocated
        ; Check if the kernel is running in RAM, if that's the case, the page it is
        ; running in as allocated
        xor a   ; 2 top bits to 0
        in a, (MMU_PAGE_0) ; Kernel is running from page 0
        sub MMU_RAM_PHYS_START_IDX
        ; Kernel is in RAM if there is no carry
        call nc, mmu_mark_page_allocated
        ; TODO: If support for RAMDISK is added, loaded by a bootloader, mark its pages
        ;       as allocated.
    ENDM

    ; Macro to map the physical address pointed by HBC to the page pointed by A.
    ; If the physical address is not a multiple of the page size, it shall be
    ; rounded down.
    ; Parameters:
    ;   HBC - 24-bit physical address to map
    ;   A - Page index to map it to. Considered valid as got after calling MMU_GET_PAGE_INDEX_FROM_VIRT_ADDRESS
    ; Returns*:
    ;   A - ERR_SUCCESS on success, error code else.
    ; Alters:
    ;   A
    ; *Not really a return as the macro shall not use ret instruction, but more like values to modify
    MACRO MMU_MAP_PHYS_HBC_TO_PAGE_A _
        LOCAL endmacro
        push bc
        ; A points to the page index, convert this to an I/O address before storing it inside C
        add MMU_PAGE_0
        ld c, a
        ; Check that the address is within 4MB as Zeal 8-bit computer only supports up to 4MB of memory.
        ld a, h
        and 0xc0
        ld a, ERR_INVALID_PHYS_ADDRESS
        jp nz, endmacro
        ; Else, we have to shift right the address 14 times and keep the result in A
        ld a, h
        rlc b
        rla
        rlc b
        rla
        ; Perform the MMU configuration now that A is correct
        out (c), a
        ; Success, return 0
        xor a
endmacro:
        pop bc
    ENDM


    ENDIF ; MMU_H