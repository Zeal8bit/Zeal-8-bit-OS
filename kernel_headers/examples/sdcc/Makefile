# All the variables below are optional. Override their value by uncommenting the corresponding line.

# Specify the shell to use for sub-commands.
# SHELL = /bin/bash

# Specify the directory containing the source files.
# INPUT_DIR=src

# Specify the build containing the compiled files.
# OUTPUT_DIR=bin

# Specify the files in the src directory to compile and the name of the final binary.
# By default, all the C files inside `INPUT_DIR` are selected, the `INPUT_DIR` prefix must not be part of the files names.
# SRCS=$(notdir $(wildcard $(INPUT_DIR)/*.c))

# Specify the name of the output binary.
# BIN=output.bin

# Specify the C compiler to use.
# ZOS_CC=sdcc

# Specify the linker to use.
# ZOS_LD=sdldz80

# Specify additional flags to pass to the compiler.
# ZOS_CFLAGS=

# Specify additional flags to pass to the linker.
# ZOS_LDFLAGS=

# Specify the `objcopy` binary that performs the ihex to bin conversion.
# By default it uses `sdobjcopy` or `objcopy` depending on which one is installed.
# OBJCOPY=$(shell which sdobjcopy objcopy | head -1)

ifndef ZOS_PATH
    $(error "Failure: ZOS_PATH variable not found. It must point to Zeal 8-bit OS path.")
endif

include $(ZOS_PATH)/kernel_headers/sdcc/base_sdcc.mk