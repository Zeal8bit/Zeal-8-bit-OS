cmake_minimum_required(VERSION 3.16)

set(ZOS_TOOLCHAIN sdcc)
include($ENV{ZOS_PATH}/cmake/zos_init.cmake)

project(exec C)

# This example builds two programs: `parent` (the init program) and `child`,
# which the parent loads and runs through the exec() syscall. Both raw
# binaries (parent.bin, child.bin) are produced by CMake.
add_executable(parent "src/parent.c")
zos_add_outputs(parent)

add_executable(child "src/child.c")
zos_add_outputs(child)
