    IFNDEF MMU_H
    DEFINE MMU_H

    ; RAM physical address
    DEFC MMU_RAM_PHYS_ADDR = 0x80000 ; 512KB

    ; Virtual page size is 16KB (so we have 4 pages)
    DEFC MMU_VIRT_PAGES_SIZE = 0x4000

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

    ; Physical page used for kernel RAM. This is the first physical page, which is
    ; 16KB wide.
    DEFC MMU_KERNEL_PHYS_PAGE = 0

    ; Physical page where programs can be loaded. This is placed after the system RAM,
    ; which is located in the first physical 16KB page.
    DEFC MMU_USER_PHYS_START_PAGE = MMU_KERNEL_PHYS_PAGE + 1

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

    ; In order to initialize the system, map the last page of memory
    ; to the first page of physical RAM. This is where the kernel data
    ; will be stored. 
    ; Physical address 0x08_0000 will be mapped to 0xC000
    MACRO MMU_INIT _
        ; Nothing special to do, the MMU doesn't need any special initialization
    ENDM

    MACRO MMU_MAP_VIRT_FROM_PHYS VIRT_PAGE, PHY_PAGE_IDX
        MMU_MAP_PHYS_ADDR((VIRT_PAGE), MMU_RAM_PHYS_ADDR + (PHY_PAGE_IDX) * MMU_VIRT_PAGES_SIZE)
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