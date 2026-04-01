cmake_minimum_required(VERSION 3.16)

set(ZOS_TOOLCHAIN sdcc_gnu)
include($ENV{ZOS_PATH}/cmake/zos_init.cmake)

project(sdcc_gnu_example C ASM)

add_executable(main
    "src/main.c"
    "src/message.s"
)

zos_add_outputs(main)
