# Variables
CC=$(shell which z88dk-z80asm z88dk.z88dk-z80asm | head -1)
LIBS=lib/strutils.lib

# Default target
all: $(LIBS)


# Create the library from the object file
lib/strutils.lib: $(addprefix src/strutils/, $(shell cat src/strutils/files.txt))
	mkdir -p build
	$(CC) -b -x$@ $^
	mv src/strutils/*.o build/

# Clean up generated files
clean:
	rm -fr $(LIBS) build/