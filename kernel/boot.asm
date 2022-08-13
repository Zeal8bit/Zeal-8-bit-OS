        INCLUDE "osconfig.asm"
        INCLUDE "errors_h.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "target_h.asm"

        ; Forward declaraction of symbols used below
        EXTERN zos_drivers_init
        EXTERN __KERNEL_BSS_head
        EXTERN __KERNEL_BSS_size

        SECTION KERNEL_TEXT
        
        PUBLIC zos_entry
zos_entry:
        ; Before setting up the stack, we need to configure the MMU
        ; this must be a macro and not a function as the SP has not been set up yet
        MMU_INIT()

        ; Map the system RAM to its virtual address
        MMU_MAP_SYSTEM_RAM(MMU_PAGE_3)

        ; Set up the stack pointer
        ld sp, CONFIG_KERNEL_STACK_ADDR

        ; If a hook has been installed for cold boot, call it
        IF CONFIG_COLDBOOT_HOOK
        call target_coldboot
        ENDIF

        IF CONFIG_EXIT_HOOK 
        call target_exit
        ENDIF

        ; Kernel RAM BSS shall be wiped now
        ld hl, __KERNEL_BSS_head
        ld de, __KERNEL_BSS_head + 1
        ld bc, __KERNEL_BSS_size - 1
        ld (hl), 0
        ldir

        ; Initialize all the drivers
        call zos_drivers_init

loop:   jp loop
