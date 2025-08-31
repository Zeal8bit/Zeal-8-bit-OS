cmake_minimum_required(VERSION 3.16)

include($ENV{ZOS_PATH}/cmake/z88dk_toolchain.cmake)

project(z88dk_example ASM)

add_executable(main "src/main.asm")
