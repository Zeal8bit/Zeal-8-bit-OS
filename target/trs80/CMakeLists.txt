# Register all the files and the include directories
zos_target_add(SRCS "video.asm"
               LINKERSCRIPT "linker.asm"
               INCLUDE "./" "./include")