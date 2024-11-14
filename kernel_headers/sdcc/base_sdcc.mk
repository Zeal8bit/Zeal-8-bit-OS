#
# SPDX-FileCopyrightText: 2024 Zeal 8-bit Computer <contact@zeal8bit.com>
#
# SPDX-License-Identifier: Apache-2.0
#

# This file is means to be included by programs based on SDCC.
# This will ease writing a Makefile for a new project that is meant to be
# compiled for Zeal 8-bit OS.
# This file can included by adding this line to any Makefile:
#	include $(ZOS_PATH)/kernel_headers/sdcc/base_sdcc.mk

SHELL ?= /bin/bash

# Directory where source files are and where the binaries will be put
INPUT_DIR ?= src
OUTPUT_DIR ?= bin

# Specify the files to compile and the name of the final binary
SRCS ?= $(notdir $(wildcard $(INPUT_DIR)/*.c))
BIN ?= output.bin

# Include directory containing Zeal 8-bit OS header files.
ifndef ZOS_PATH
$(error "Please define ZOS_PATH environment variable. It must point to Zeal 8-bit OS source code path.")
endif

ZOS_INCLUDE=$(ZOS_PATH)/kernel_headers/sdcc/include/
# Regarding the linking process, we will need to specify the path to the crt0 REL file.
# It contains the boot code for C programs as well as all the C functions performing syscalls.
CRT_REL=$(ZOS_PATH)/kernel_headers/sdcc/bin/zos_crt0.rel


# Compiler, linker and flags related variables
ZOS_CC ?= sdcc
ZOS_LD ?= sdldz80

# Specify Z80 as the target, compile without linking, and place all the code in TEXT section
# (_CODE must be replace).
CFLAGS = -mz80 -c --codeseg TEXT -I$(ZOS_INCLUDE) $(ZOS_CFLAGS)

# Make sure the whole program is relocated at 0x4000 as request by Zeal 8-bit OS.
LDFLAGS = -n -mjwx -i -b _HEADER=0x4000 -k $(ZOS_PATH)/kernel_headers/sdcc/lib -l z80 $(ZOS_LDFLAGS)

# Binary used to convert ihex to binary
OBJCOPY ?= $(shell which sdobjcopy objcopy gobjcopy | head -1)

# Generate the intermediate Intel Hex binary name
BIN_HEX=$(patsubst %.bin,%.ihx,$(BIN))
# Generate the rel names for C source files. Only keep the file names, and add output dir prefix.
SRCS_OUT_DIR=$(addprefix $(OUTPUT_DIR)/,$(SRCS))
SRCS_REL=$(patsubst %.c,%.rel,$(SRCS_OUT_DIR))


.PHONY: all clean

all:: clean $(OUTPUT_DIR) $(OUTPUT_DIR)/$(BIN_HEX) $(OUTPUT_DIR)/$(BIN)
	@bash -c 'echo -e "\x1b[32;1mSuccess, binary generated: $(OUTPUT_DIR)/$(BIN)\x1b[0m"'

$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)

# Generate a REL file for each source file. In fact, SDCC doesn't support compiling multiple source file
# at once. We have to create the same directory structure in output dir too.
$(SRCS_REL): $(OUTPUT_DIR)/%.rel : $(INPUT_DIR)/%.c
	@mkdir -p $(OUTPUT_DIR)/$(dir $*)
	$(ZOS_CC) $(CFLAGS) -o $(OUTPUT_DIR)/$(dir $*) $<

# Generate the final Intel HEX binary.
$(OUTPUT_DIR)/$(BIN_HEX): $(CRT_REL) $(SRCS_REL)
	$(ZOS_LD) $(LDFLAGS) $(OUTPUT_DIR)/$(BIN_HEX) $(CRT_REL) $(SRCS_REL)

# Convert the Intel HEX file to an actual binary.
$(OUTPUT_DIR)/$(BIN):
	$(OBJCOPY) --input-target=ihex --output-target=binary $(OUTPUT_DIR)/$(BIN_HEX) $(OUTPUT_DIR)/$(BIN)

clean:
	rm -fr ./$(OUTPUT_DIR)