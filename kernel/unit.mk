
SRCS = rst_vectors.asm boot.asm drivers.asm strutils.asm disks.asm vfs.asm time.asm log.asm syscalls.asm loader.asm fs/rawtable.asm

ifdef CONFIG_KERNEL_ENABLE_ZEALFS_SUPPORT
	SRCS += fs/zealfs.asm
endif
