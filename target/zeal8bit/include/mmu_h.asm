    IFNDEF MMU_H
    DEFINE MMU_H

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

    MACRO MMU_MAP_PHYS_ADDR page, address
        ld a, address >> 14
        out (page), a
    ENDM

    ; In order to initialize the system, map the last page of memory
    ; to the first page of physical RAM. This is where the kernel data
    ; will be stored. 
    ; Physical address 0x08_0000 will be mapped to 0xC000
    MACRO MMU_INIT _
        MMU_MAP_PHYS_ADDR(MMU_PAGE_1, 0x089000)
        MMU_MAP_PHYS_ADDR(MMU_PAGE_2, 0x08A000)
        MMU_MAP_PHYS_ADDR(MMU_PAGE_3, 0x088000)
    ENDM

    MACRO MMU_MAP_SYSTEM_RAM PAGE_NB
        MMU_MAP_PHYS_ADDR(PAGE_NB, 0x088000)
    ENDM

    ENDIF ; MMU_H