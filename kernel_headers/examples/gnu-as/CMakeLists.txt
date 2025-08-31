cmake_minimum_required(VERSION 3.16)

set(ZOS_TOOLCHAIN gnu)
include($ENV{ZOS_PATH}/cmake/zos_init.cmake)

project(gnu_as_example ASM)
add_executable(main "src/main.asm")

# If the project needs to override the default LINKER_FLAGS, uncomment this line:
# set(CMAKE_EXE_LINKER_FLAGS "")

# Then it's possible to set a linker script for example
# target_link_options(main PUBLIC "-TPath_to_file.ld")

# Convert the generated ELF into a raw binary
elf_to_bin(main)
