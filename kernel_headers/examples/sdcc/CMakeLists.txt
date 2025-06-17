#
# SPDX-FileCopyrightText: 2025 Zeal 8-bit Computer <contact@zeal8bit.com>
#
# SPDX-License-Identifier: Apache-2.0
#
cmake_minimum_required(VERSION 3.16)

# When using CMake as a build system, it's possible to mix ASM and C in the compilation
project(example C ASM)

add_executable(hello "src/main.c" "src/str.c")

ihx_to_bin(hello)
