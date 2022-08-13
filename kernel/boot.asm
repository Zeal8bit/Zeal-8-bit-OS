        INCLUDE "mmu_h.asm"
        INCLUDE "osconfig.asm"

        SECTION KERNEL_TEXT
        
        PUBLIC zos_entry
zos_entry:
        ; Before setting up the stack, we need to configure the MMU
        ; this must be a macro and not a function as the SP has not been set up yet
        MMU_INIT()

        ; Set up the stack pointer
        ld sp, CONFIG_KERNEL_STACK_ADDR

loop:   jp loop
