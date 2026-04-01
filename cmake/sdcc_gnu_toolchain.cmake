set(CMAKE_MODULE_PATH "$ENV{ZOS_PATH}/cmake/Modules" ${CMAKE_MODULE_PATH})

set(CMAKE_SYSTEM_NAME ZOS)
set(CMAKE_SYSTEM_PROCESSOR Z80)

set(CMAKE_C_COMPILER_WORKS TRUE CACHE INTERNAL "")
set(CMAKE_C_COMPILER_FORCED TRUE CACHE INTERNAL "")
set(CMAKE_ASM_COMPILER_WORKS TRUE CACHE INTERNAL "")
# Disable C++
set(CMAKE_CXX_COMPILER "" CACHE INTERNAL "")
set(CMAKE_CXX_COMPILER_WORKS TRUE CACHE INTERNAL "")

# Reuse the SDCC C platform file, but switch it to the GNU binutils flow.
set(ZOS_SDCC_USE_GNU_BINUTILS TRUE CACHE INTERNAL "")

set(CMAKE_C_COMPILER sdcc)
set(CMAKE_C_DEPFILE_STYLE NONE)

set(CMAKE_ASM_COMPILER z80-elf-as)
set(CMAKE_LINKER z80-elf-ld)
set(CMAKE_AR z80-elf-ar)
set(CMAKE_OBJCOPY z80-elf-objcopy)
set(CMAKE_OBJDUMP z80-elf-objdump)
set(CMAKE_NM z80-elf-nm)

# SDCC still provides the C headers and startup/runtime object.
set(CMAKE_C_FLAGS_INIT "-mz80 -I$ENV{ZOS_PATH}/kernel_headers/sdcc/include/ --codeseg TEXT")

# Assembly sources are expected to use the GNU AS Zeal headers.
set(ZOS_GNU_SYSROOT "$ENV{ZOS_PATH}/kernel_headers/gnu-as")
set(CMAKE_ASM_FLAGS_INIT "-I${ZOS_GNU_SYSROOT}/ -I${ZOS_GNU_SYSROOT}/include")

# GNU ld can consume SDCC relocatables with -sdcc, which lets us keep the
# Zeal crt0 while linking the final ELF with GNU binutils.
set(CMAKE_EXE_LINKER_FLAGS "-Ttext=0x4000")

set(CMAKE_C_LINK_EXECUTABLE
    "<CMAKE_LINKER> <LINK_FLAGS> -o <TARGET> <OBJECTS> <LINK_LIBRARIES>"
)
set(CMAKE_ASM_LINK_EXECUTABLE
    "<CMAKE_LINKER> <LINK_FLAGS> -o <TARGET> <OBJECTS> <LINK_LIBRARIES>"
)
set(CMAKE_ASM_COMPILE_OBJECT
    "<CMAKE_ASM_COMPILER> <DEFINES> <INCLUDES> <FLAGS> -o <OBJECT> <SOURCE>"
)
