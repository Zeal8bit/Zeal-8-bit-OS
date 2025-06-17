# Set the linker script

# Optional MMU support
if(CONFIG_KERNEL_TARGET_HAS_MMU)
    set(MMU_FILE mmu.asm)
else()
    set(MMU_FILE "")
endif()

# Source files common to MMU and no-MMU configurations
set(SRCS
    pio.asm
    i2c.asm
    keyboard.asm
    romdisk.asm
    ${MMU_FILE}
    interrupt_vect.asm
    eeprom.asm
)

# Conditional keyboard source
if(CONFIG_TARGET_KEYBOARD_PS2)
    list(APPEND SRCS keyboard/ps2.asm)
else()
    list(APPEND SRCS keyboard/parl.asm)
endif()

# Conditionally prepend uart.asm if it's stdout
if(CONFIG_TARGET_STDOUT_UART)
    # Insert at the beginning
    list(INSERT SRCS 0 uart.asm)
else()
    list(APPEND SRCS uart.asm)
endif()

# Same logic for video
if(CONFIG_TARGET_STDOUT_VIDEO)
    list(INSERT SRCS 0 video.asm)
elseif(CONFIG_TARGET_ENABLE_VIDEO)
    list(APPEND SRCS video.asm)
endif()

# Optional CF/TF support
if(CONFIG_TARGET_ENABLE_COMPACTFLASH)
    list(APPEND SRCS compactflash.asm)
endif()

if(CONFIG_TARGET_ENABLE_TFCARD)
    list(APPEND SRCS tf.asm)
endif()

# Register all the files and the include directories
zos_target_add(SRCS ${SRCS}
               LINKERSCRIPT "linker.asm"
               INCLUDE "./" "./include")

# Calculate the offset of the ROMDISK relatively to the kernel physical address
math(EXPR ROMDISK_OFFSET "${CONFIG_ROMDISK_ADDRESS} - ${CONFIG_KERNEL_PHYS_ADDRESS}")

# Create a ROM image that will contain the OS binary with the romdisk
zos_create_rom_image(OUTPUT "${CMAKE_BINARY_DIR}/os_with_romdisk.img"
                     DISK_OFFSET "${ROMDISK_OFFSET}")