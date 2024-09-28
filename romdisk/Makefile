# Final binary name
BIN=init.bin
# Source files to assemble
SRCS=init.asm parse.asm  cat.asm ls.asm less.asm opt.asm mkdir.asm cd.asm rm.asm \
	 errors.asm uart.asm strutils.asm date.asm cp.asm misc.asm hexdump.asm \
	 sleep.asm expr.asm echo.asm touch.asm
# Output directory to place binaries in
BUILDIR=build

# Name of the image file to make
IMG=disk.img
# Files to pack inside the image file
FILES_IN_IMG=$(BUILDIR)/$(BIN) simple.txt

# If z88dk has been install through snap, the binary may be prefixed with "z88dk"
# So choose any of z88dk-* or z88dk.z88dk-*, as long as one exists
CC=$(shell which z88dk-z80asm z88dk.z88dk-z80asm | head -1)

# On some versions of z88dk, -Oxxx switch does not generate the init_TEXT.bin file,
# it only creates empty init.bin. Generate all the binaries in the current directory
# and move them manually
ASMFLAGS=-I$(ZOS_PATH)/kernel_headers/z88dk-z80asm -m -b


.PHONY: all clean

all: clean
	@ ( test -n "$(EXTRA_ROMDISK_FILES)" && \
	    echo "Extra files detected: $(EXTRA_ROMDISK_FILES)" ) || \
	    echo "No extra file to pack into romdisk"
	@mkdir -p $(BUILDIR)
	@echo "Creating romdisk"
	$(CC) $(ASMFLAGS) $(SRCS)
	@echo "Moving generated files"
	mv *.o ./$(BUILDIR) && mv *.map ./$(BUILDIR) && mv $(basename $(BIN))*.bin ./$(BUILDIR)
	@# For some reasons, z88dk-z80asm will create an empty `init.bin` file, remove it
	@rm -f $(BUILDIR)/$(BIN) && mv $(BUILDIR)/*_TEXT.bin $(BUILDIR)/$(BIN)
	@echo "Packing the files"
	pack $(IMG) $(FILES_IN_IMG) $(EXTRA_ROMDISK_FILES)

clean:
	rm -rf build/ $(IMG)
