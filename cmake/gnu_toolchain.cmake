set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR z80)

# Disable C and C++
set(CMAKE_C_COMPILER "" CACHE INTERNAL "")
set(CMAKE_CXX_COMPILER "" CACHE INTERNAL "")

set(CMAKE_ASM_COMPILER z80-elf-as)
set(CMAKE_LINKER z80-elf-ld)
set(CMAKE_AR z80-elf-ar)
set(CMAKE_OBJCOPY z80-elf-objcopy)
set(CMAKE_OBJDUMP z80-elf-objdump)
set(CMAKE_NM z80-elf-nm)

set(CMAKE_ASM_COMPILE_OBJECT "<CMAKE_ASM_COMPILER> <DEFINES> <FLAGS> <INCLUDES> <SOURCE> -o <OBJECT>")

set(CMAKE_ASM_FLAGS_INIT "-I$ENV{ZOS_PATH}/kernel_headers/gnu-as/")

# Using CMAKE_EXE_LINKER_FLAGS_INIT has no effect...
set(CMAKE_EXE_LINKER_FLAGS "-Ttext=0x4000")

# Helper to convert an ELF file to a raw binary
function(elf_to_bin target)
    set(bin_file "${CMAKE_CURRENT_BINARY_DIR}/${target}.bin")
    add_custom_target(${target}_bin ALL
        COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:${target}> ${bin_file}
        DEPENDS ${target}
        COMMENT "Converting ELF to raw binary"
        VERBATIM
    )
    set_property(TARGET ${target}_bin PROPERTY RAW_BINARY ${bin_file})
endfunction()