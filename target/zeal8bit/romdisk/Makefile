CC=z88dk-z80asm
BIN=init.bin
SRCS=init.asm parse.asm ls.asm less.asm opt.asm mkdir.asm cd.asm rm.asm errors.asm uart.asm strutils.asm
IMG=disk.img
BUILDIR=build
FILES_IN_IMG=$(BUILDIR)/$(BIN) simple.txt

phony: all clean

all: clean 
	@mkdir -p $(BUILDIR)
	@echo "Creating romdisk..."
	$(CC) -O$(BUILDIR) -m -b $(SRCS)
	@# For some reasons, z88dk-z80asm will create an empty `init.bin` file, remove it
	@rm -f $(BUILDIR)/$(BIN) && mv $(BUILDIR)/*_TEXT.bin $(BUILDIR)/$(BIN)
	@echo "Packing the files"
	pack $(IMG) $(FILES_IN_IMG)

clean:
	rm -rf build/ $(IMG)
