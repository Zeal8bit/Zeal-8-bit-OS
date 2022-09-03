CC=z88dk-z80asm
BIN=init.bin
SRCS=init.asm parse.asm ls.asm less.asm opt.asm mkdir.asm cd.asm rm.asm errors.asm
IMG=disk.img
FILES_IN_IMG=init.asm $(BIN) simple.txt

phony: all clean

all: clean 
	@echo "Creating romdisk..."
	$(CC) -b $(SRCS)
	# For some reasons, z88dk-z80asm will create an empty `init.bin` file, remove it
	@rm -f $(BIN) && mv *_TEXT.bin $(BIN)
	@echo "Packing the files"
	pack $(IMG) $(FILES_IN_IMG)

clean:
	rm -f *.o *.bin *.err *.map
