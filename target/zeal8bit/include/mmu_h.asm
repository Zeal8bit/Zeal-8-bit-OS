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

    ; Internal macro used to map a physicall address to a virtual page 
    MACRO MMU_MAP_PHYS_ADDR page, address
        ld a, address >> 14  ; Virtual address are 16 - 2 = 14 bits wide
        out (page), a
    ENDM

    ; In order to initialize the system, map the last page of memory
    ; to the first page of physical RAM. This is where the kernel data
    ; will be stored. 
    ; Physical address 0x08_0000 will be mapped to 0xC000
    MACRO MMU_INIT _
        ; Nothing special to do, the MMU doesn't need any special initialization
    ENDM

    MACRO MMU_MAP_VIRT_FROM_PHYS VIRT_PAGE, PHY_PAGE_IDX
        ; Use this when the Verilog will be fixed with 22-bit addresses
        ; MMU_MAP_PHYS_ADDR((VIRT_PAGE), MMU_RAM_PHYS_ADDR + (PHY_PAGE_IDX) * MMU_VIRT_PAGES_SIZE)
        ; Page must all have bit 15 equal to 1 because of the current FPGA implementation
        ; else, should be: ld a, 0x20 + PHY_PAGE_IDX
        IF (PHY_PAGE_IDX) % 2 == 0
        ld a, 0x20 + (PHY_PAGE_IDX + 1) * 2
        ELSE
        ld a, 0x20 + ((PHY_PAGE_IDX) * 2 + 1)
        ENDIF
        out (VIRT_PAGE), a
    ENDM

    ENDIF ; MMU_H