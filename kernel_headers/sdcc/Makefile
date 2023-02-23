SHELL := /bin/bash
AS=sdasz80
ASFLAGS=-f -o

.PHONY: all clean

# Make the library out of the ASM file
all: bin/zos_crt0.rel

# We could create a library (.lib) out of the syscalls C functions with: sdar -rc zeal8bitos.lib zeal8bitos.rel
# But it will be simpler for users if they are embedded inside the crt0.
# crt0 asm file MUST BE THE FIRST to be assembled.
bin/zos_crt0.rel: src/zos_crt0.asm src/zeal8bitos.asm
	@echo -e "\x1b[1;32mAssembling Zeal 8-bit OS library and crt0 files...\x1b[0m"
	$(AS) $(ASFLAGS) $@ $^

lib/z80.lib:
	python3 lib/patch_lib_code.py /usr/local/share/sdcc/lib/z80/z80.lib lib/z80.lib

clean:
	rm -f bin/*.rel
