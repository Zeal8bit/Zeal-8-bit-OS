cmake_minimum_required(VERSION 3.16)

set(ZOS_TOOLCHAIN z88dk)
include($ENV{ZOS_PATH}/cmake/zos_init.cmake)

project(z88dk_example ASM)

add_executable(main "src/main.asm")
