# Register all the files and the include directories
zos_target_add(SRCS "uart.asm" "pio.asm" "romdisk.asm" "ram1disk.asm" "interrupt_vect.asm"
               LINKERSCRIPT "linker.asm"
               FLAGS "-mez80_z80"
               INCLUDE "./" "./include")

# Create a ROM image that will contain the OS binary with the romdisk
zos_create_rom_image(OUTPUT "${CMAKE_BINARY_DIR}/os_with_romdisk.img"
                     DISK_OFFSET "0x10000")