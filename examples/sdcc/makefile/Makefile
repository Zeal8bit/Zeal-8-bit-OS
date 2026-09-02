ifndef ZOS_PATH
    $(error "Failure: ZOS_PATH variable not found. It must point to Zeal 8-bit OS path.")
endif

# This example shows how to build a program with a plain Makefile instead of
# CMake, using the SDCC toolchain. It reuses the source code of the
# `hello_world` example (../hello_world/src).
INPUT_DIR=../hello_world/src

# Name of the final binary
BIN = makefile.bin

include $(ZOS_PATH)/sdk/sdcc/base_sdcc.mk
