cmake_minimum_required(VERSION 3.16)

set(ZOS_TOOLCHAIN sdcc)
include($ENV{ZOS_PATH}/cmake/zos_init.cmake)

project(mouse C)

add_executable(mouse "src/main.c")

zos_add_outputs(mouse)
