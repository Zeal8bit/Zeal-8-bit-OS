# Set the linker script

# Optional MMU support
if(CONFIG_KERNEL_TARGET_HAS_MMU)
    set(mmu_file mmu.asm)
else()
    set(mmu_file "")
endif()

# Source files common to MMU and no-MMU configurations
set(srcs
    pio.asm
    i2c.asm
    keyboard.asm
    ${mmu_file}
    interrupt_vect.asm
    eeprom.asm
)

# Only include the romdisk driver if enabled in the menuconfig
if (CONFIG_ENABLE_ROMDISK)
    list(APPEND srcs romdisk.asm)
endif()

# Conditional keyboard source
if(CONFIG_TARGET_KEYBOARD_PS2)
    list(APPEND srcs keyboard/ps2.asm)
else()
    list(APPEND srcs keyboard/parl.asm)
endif()

# Conditionally prepend uart.asm if it's stdout
if(CONFIG_TARGET_STDOUT_UART)
    # Insert at the beginning
    list(INSERT srcs 0 uart.asm)
else()
    list(APPEND srcs uart.asm)
endif()

# Same logic for video
if(CONFIG_TARGET_STDOUT_VIDEO)
    list(INSERT srcs 0 video.asm)
elseif(CONFIG_TARGET_ENABLE_VIDEO)
    list(APPEND srcs video.asm)
endif()

# Optional CF/TF support
if(CONFIG_TARGET_ENABLE_COMPACTFLASH)
    list(APPEND srcs compactflash.asm)
endif()

if(CONFIG_TARGET_ENABLE_TFCARD)
    list(APPEND srcs tf.asm)
endif()

# Register all the files and the include directories
zos_target_add(SRCS ${srcs}
               LINKERSCRIPT "linker.yaml"
               INCLUDE "./" "./include")
