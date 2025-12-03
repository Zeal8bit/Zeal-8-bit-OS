# Register all the files and the include directories
zos_target_add(SRCS "uart.asm" "pio.asm" "romdisk.asm" "ram1disk.asm" "interrupt_vect.asm"
               LINKERSCRIPT "linker.asm"
               FLAGS "-mez80_z80"
               INCLUDE "./" "./include")
