        INCLUDE "osconfig.asm"
        INCLUDE "errors_h.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "target_h.asm"

        ; Forward declaraction of symbols used below
        EXTERN zos_drivers_init
        EXTERN zos_vfs_init
        EXTERN zos_sys_init
        EXTERN zos_log_init
        EXTERN zos_vfs_restore_std
        EXTERN zos_disks_init
        EXTERN zos_disks_get_default
        EXTERN zos_load_file
        EXTERN __KERNEL_BSS_head
        EXTERN __KERNEL_BSS_size

        SECTION KERNEL_TEXT
        
        PUBLIC zos_entry
zos_entry:
        ; Before setting up the stack, we need to configure the MMU
        ; this must be a macro and not a function as the SP has not been set up yet
        MMU_INIT()

        ; Map the kernel RAM to the last virtual page
        MMU_MAP_VIRT_FROM_PHYS(MMU_PAGE_3, MMU_KERNEL_PHYS_PAGE)

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

        ; Initialize the disk module
        call zos_disks_init

        ; Initialize the VFS
        call zos_vfs_init

        ; Initialize the logger
        call zos_log_init

        ; Initialize all the drivers
        call zos_drivers_init

        ; Setup the default stdin and stdout in the vfs
        call zos_vfs_restore_std

        ; Set up the syscalls
        call zos_sys_init

        ; Load the init file from the default disk drive
        ld hl, _zos_default_init
        jp zos_load_file

_zos_default_init:
        DEFM "init.bin", 0
        ; Define the boilerplate to print as soon as 
        ; a logging function is available
        PUBLIC zos_boilerplate
zos_boilerplate:
        INCBIN "version.txt"
        DEFB "\n", 0