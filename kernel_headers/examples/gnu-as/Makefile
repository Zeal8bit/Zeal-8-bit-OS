SHELL := /bin/bash

SRCS = main.asm
BIN = main.bin

# Only extract the following sections from the ELF file
SECTIONS=.text .data

# Assembler flags, provide a path to the Zeal 8-bit OS header files. The option `-g` is not mandatory,
# it will only generate more debug symbols in the final ELF file, making it possible to use utils
# like `addr2line`. It can be omitted.
ASFLAGS = -I$(ZOS_INCLUDE) -g
# The binary must be relocated at address 0x4000 since this is where Zeal 8-bit OS kernel will copy
# the program and execute it from. Make sure all the other sections follow the `.text` section.
# If not, it may be necessary to make a custom Linker Script file `.ld` and provide it at link time.
LDFLAGS = -Ttext 0x4000

# Directory where source files are and where the binaries will be put
INPUT_DIR = src
OUTPUT_DIR = bin
OBJS := $(addprefix $(OUTPUT_DIR)/, $(SRCS:.asm=.asm.o))

# Include directory containing Zeal 8-bit OS header file.
ifndef ZOS_PATH
$(error "Please define ZOS_PATH environment variable. It must point to Zeal 8-bit OS source code path.")
endif
ZOS_INCLUDE = $(ZOS_PATH)/kernel_headers/gnu-as/

# Assembler binary name
AS = z80-elf-as
LD = z80-elf-ld
OBJCPY = z80-elf-objcopy
.PHONY: all

all: $(OUTPUT_DIR) $(OUTPUT_DIR)/$(BIN)

$(OUTPUT_DIR)/$(BIN): $(OBJS)
	$(LD) $(LDFLAGS) -o $@.elf $<
	$(OBJCPY) $(addprefix --only-section=, $(SECTIONS)) -O binary $@.elf $@


$(OUTPUT_DIR)/%.asm.o: $(INPUT_DIR)/%.asm
	$(AS) $(ASFLAGS) -o $@ $<

$(OUTPUT_DIR):
	mkdir -p $@

clean:
	rm -r bin/