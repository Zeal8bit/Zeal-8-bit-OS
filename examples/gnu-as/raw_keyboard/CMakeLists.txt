cmake_minimum_required(VERSION 3.16)

set(ZOS_TOOLCHAIN gnu)
include($ENV{ZOS_PATH}/cmake/zos_init.cmake)

project(raw_keyboard ASM)
add_executable(main "src/main.asm")

# Add ZOS output, i.e. generate a raw binary out of the compiled ELF
zos_add_outputs(main)
