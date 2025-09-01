cmake_minimum_required(VERSION 3.16)

set(ZOS_TOOLCHAIN sdcc)
include($ENV{ZOS_PATH}/cmake/zos_init.cmake)

# When using CMake as a build system, it's possible to mix ASM and C in the compilation
project(example C ASM)

add_executable(hello "src/main.c" "src/str.c")

zos_add_outputs(hello)
