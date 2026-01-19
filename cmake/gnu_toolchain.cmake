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

# Zeal 8-bit OS libraries for GNU-AS toolchain
set(ZOS_GNU_SYSROOT $ENV{ZOS_PATH}/kernel_headers/gnu-as)
set(CMAKE_ASM_FLAGS_INIT "-I${ZOS_GNU_SYSROOT}/ -I${ZOS_GNU_SYSROOT}/include")
link_directories("${ZOS_GNU_SYSROOT}/lib")

# Using CMAKE_EXE_LINKER_FLAGS_INIT has no effect...
set(CMAKE_EXE_LINKER_FLAGS "-Ttext=0x4000")

