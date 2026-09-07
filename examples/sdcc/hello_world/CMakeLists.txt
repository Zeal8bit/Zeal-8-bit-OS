cmake_minimum_required(VERSION 3.16)

set(ZOS_TOOLCHAIN sdcc)
include($ENV{ZOS_PATH}/cmake/zos_init.cmake)

project(hello_world C)

add_executable(hello_world "src/main.c")

zos_add_outputs(hello_world)
