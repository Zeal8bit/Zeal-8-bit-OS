cmake_minimum_required(VERSION 3.16)

set(ZOS_TOOLCHAIN sdcc)
include($ENV{ZOS_PATH}/cmake/zos_init.cmake)

project(raw_keyboard C)

add_executable(raw_keyboard "src/main.c")

zos_add_outputs(raw_keyboard)
