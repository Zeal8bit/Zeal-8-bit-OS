
# Kernel core related files
SRCS = rst_vectors.asm boot.asm drivers.asm strutils.asm disks.asm vfs.asm time.asm log.asm

ifdef CONFIG_KERNEL_TARGET_HAS_MMU
	SRCS += syscalls.asm loader.asm
else
	SRCS += syscalls_nommu.asm loader_nommu.asm
endif

# Filesystems related files
SRCS += fs/rawtable.asm

ifdef CONFIG_KERNEL_ENABLE_ZEALFS_SUPPORT
	ifdef CONFIG_KERNEL_ZEALFS_V1
		SRCS += fs/zealfs_v1.asm
	else ifdef CONFIG_KERNEL_ZEALFS_V2
		SRCS += fs/zealfs_v2.asm
	endif
endif

ifdef CONFIG_ENABLE_EMULATION_HOSTFS
	SRCS += fs/hostfs.asm
endif
