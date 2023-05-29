SHELL := /bin/bash

SRCS = main.asm
BIN = main.bin

# Directory where source files are and where the binaries will be put
INPUT_DIR = src
OUTPUT_DIR = bin

# Include directory containing Zeal 8-bit OS header file.
ifndef ZOS_PATH
$(error "Please define ZOS_PATH environment variable. It must point to Zeal 8-bit OS source code path.")
endif
ZOS_INCLUDE = $(ZOS_PATH)/kernel_headers/z88dk-z80asm/

# Assembler binary name
ASM = z88dk-z80asm
# Assembler flags
ASMFLAGS = -b -I$(ZOS_INCLUDE) -O$(OUTPUT_DIR)

.PHONY: all

all: $(OUTPUT_DIR) $(BIN)

$(BIN): $(addprefix $(INPUT_DIR)/, $(SRCS))
	$(ASM) $(ASMFLAGS) -o$@ $^


$(OUTPUT_DIR):
	mkdir -p $@

clean:
	rm -r bin/