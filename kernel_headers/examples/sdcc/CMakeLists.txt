#
# SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
#
# SPDX-License-Identifier: Apache-2.0
#
cmake_minimum_required(VERSION 3.16)
project(example NONE)
include($ENV{ZOS_PATH}/kernel_headers/sdcc/base_sdcc.cmake)

zos_create_executable(NAME newexample
                      SRCS "src/main.c" "src/str.c"
                      INCLUDES "include"
                      COMPILE_FLAGS "-DHELLO")

