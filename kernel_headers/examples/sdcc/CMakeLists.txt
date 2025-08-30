cmake_minimum_required(VERSION 3.16)

# When using CMake as a build system, it's possible to mix ASM and C in the compilation
project(example C ASM)

add_executable(hello "src/main.c" "src/str.c")

ihx_to_bin(hello)
