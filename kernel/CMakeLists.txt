# Base kernel sources
set(KERNEL_SRCS
    rst_vectors.asm
    boot.asm
    drivers.asm
    strutils.asm
    disks.asm
    vfs.asm
    time.asm
    log.asm
)

if(CONFIG_KERNEL_TARGET_HAS_MMU)
    list(APPEND KERNEL_SRCS syscalls.asm loader.asm)
else()
    list(APPEND KERNEL_SRCS syscalls_nommu.asm loader_nommu.asm)
endif()

list(APPEND KERNEL_SRCS fs/rawtable.asm)

if(CONFIG_KERNEL_ENABLE_MBR_SUPPORT)
    list(APPEND KERNEL_SRCS fs/mbr.asm)
endif()

if(CONFIG_KERNEL_ENABLE_ZEALFS_SUPPORT)
    if(CONFIG_KERNEL_ZEALFS_V1)
        list(APPEND KERNEL_SRCS fs/zealfs_v1.asm)
    elseif(CONFIG_KERNEL_ZEALFS_V2)
        list(APPEND KERNEL_SRCS fs/zealfs_v2.asm)
    endif()
endif()

if(CONFIG_ENABLE_EMULATION_HOSTFS)
    list(APPEND KERNEL_SRCS fs/hostfs.asm)
endif()

zos_kernel_add(SRCS ${KERNEL_SRCS})
