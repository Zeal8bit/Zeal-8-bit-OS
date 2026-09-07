cmake_minimum_required(VERSION 3.16)

set(ZOS_TOOLCHAIN sdcc)
include($ENV{ZOS_PATH}/cmake/zos_init.cmake)

# When using CMake as a build system, it's possible to mix ASM and C in the compilation
project(dir_listing C ASM)

add_executable(dir_listing "src/main.c")

zos_add_outputs(dir_listing)
