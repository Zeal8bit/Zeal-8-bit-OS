# Final binary name
BIN=init.bin
# Source files to assemble
SRCS=init.asm parse.asm ls.asm less.asm opt.asm mkdir.asm cd.asm rm.asm \
	 errors.asm uart.asm strutils.asm date.asm cp.asm misc.asm hexdump.asm
# Output directory to place binaries in
BUILDIR=build

# Name of the image file to make
IMG=disk.img
# Files to pack inside the image file
FILES_IN_IMG=$(BUILDIR)/$(BIN) simple.txt

# Variables related to the assembler and the flags to use
CC=z88dk-z80asm
ASMFLAGS=-I$(ZOS_PATH)/kernel_headers/z88dk-z80asm -O$(BUILDIR) -m -b


.PHONY: all clean

all: clean
	@ ( test -n "$(EXTRA_ROMDISK_FILES)" && \
	    echo "Extra files detected: $(EXTRA_ROMDISK_FILES)" ) || \
	    echo "No extra file to pack into romdisk"
	@mkdir -p $(BUILDIR)
	@echo "Creating romdisk..."
	$(CC) $(ASMFLAGS) $(SRCS)
	@# For some reasons, z88dk-z80asm will create an empty `init.bin` file, remove it
	@rm -f $(BUILDIR)/$(BIN) && mv $(BUILDIR)/*_TEXT.bin $(BUILDIR)/$(BIN)
	@echo "Packing the files"
	pack $(IMG) $(FILES_IN_IMG) $(EXTRA_ROMDISK_FILES)

clean:
	rm -rf build/ $(IMG)
