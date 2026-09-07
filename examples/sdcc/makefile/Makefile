ifndef ZOS_PATH
    $(error "Failure: ZOS_PATH variable not found. It must point to Zeal 8-bit OS path.")
endif

# This example showcases the Makefile build system for the SDCC toolchain.
# It reuses the source code of the `hello_world` example
# (../hello_world/src): base_sdcc.mk compiles every C file found in INPUT_DIR.
INPUT_DIR=../hello_world/src

# Name of the final binary
BIN = makefile.bin

include $(ZOS_PATH)/sdk/sdcc/base_sdcc.mk
