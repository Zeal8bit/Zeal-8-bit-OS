        ; Code and read-only data
        SECTION RST_VECTORS
        ORG 0
        SECTION SYSCALL_TABLE
        SECTION KERNEL_TEXT
        SECTION KERNEL_RODATA
        SECTION KERNEL_DRV_TEXT
        SECTION KERNEL_DRV_VECTORS

        ; RAM data
        SECTION KERNEL_BSS
        ORG 0xC000