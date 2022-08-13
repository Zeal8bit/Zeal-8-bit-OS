
SRCS = rst_vectors.asm boot.asm drivers.asm strutils.asm disks.asm vfs.asm log.asm syscalls.asm loader.asm fs/rawtable.asm

#ifeq ($(CONFIG_BOOL), y)
#    SRCS += file.asm
#else
#    SRCS += nofile.asm
#endif
