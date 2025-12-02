# Before including the Makefiles, include the configuration one if it exists
-include $(KCONFIG_CONFIG)

# Final binary name
BIN=init.bin
# Source files to assemble

# shell core
SRCS=init.asm parse.asm opt.asm errors.asm uart.asm date.asm misc.asm
# shell commands that always exist
SRCS += cd.asm sleep.asm expr.asm

# Output directory to place binaries in
BUILDIR=build

# Name of the image file to make
IMG=disk.img
# Files to pack inside the image file
FILES_IN_IMG=

ifdef CONFIG_ROMDISK_INCLUDE_INIT_BIN
    FILES_IN_IMG += $(BUILDIR)/$(BIN)
endif

ifdef CONFIG_ROMDISK_INCLUDE_SIMPLE_TXT
    FILES_IN_IMG += simple.txt
endif

EXTRA_ROMDISK_FILES := $(wildcard $(EXTRA_ROMDISK_FILES))


# If z88dk has been install through snap, the binary may be prefixed with "z88dk"
# So choose any of z88dk-* or z88dk.z88dk-*, as long as one exists
CC=$(shell which z88dk-z80asm z88dk.z88dk-z80asm | head -1)

# On some versions of z88dk, -Oxxx switch does not generate the init_TEXT.bin file,
# it only creates empty init.bin. Generate all the binaries in the current directory
# and move them manually
INCLUDES=-I$(ZOS_PATH)/kernel_headers/z88dk-z80asm -I$(ZOS_PATH)/kernel_headers/z88dk-z80asm/include
LIBS=-L$(ZOS_PATH)/kernel_headers/z88dk-z80asm/lib
ASMFLAGS=$(INCLUDES) $(LIBS) -lstrutils.lib -m -b


ifdef CONFIG_INITBIN_ENABLE_COREUTILS
	ASMFLAGS += -DCONFIG_ENABLE_COREUTILS=1
else
	SRCS += cat.asm mkdir.asm rm.asm cp.asm hexdump.asm echo.asm less.asm xfer.asm ls.asm
endif


.PHONY: all clean

all: clean
ifdef CONFIG_ROMDISK_INCLUDE_INIT_BIN
	@mkdir -p $(BUILDIR)
	@echo "Creating romdisk"
	$(CC) $(ASMFLAGS) $(SRCS)
	@echo "Moving generated files"
	mv *.o ./$(BUILDIR) && mv *.map ./$(BUILDIR) && mv $(basename $(BIN))*.bin ./$(BUILDIR)
	@# For some reasons, z88dk-z80asm will create an empty `init.bin` file, remove it
	@rm -f $(BUILDIR)/$(BIN) && mv $(BUILDIR)/*_TEXT.bin $(BUILDIR)/$(BIN)
else
	@echo "Skipping init.bin build (CONFIG_ROMDISK_INCLUDE_INIT_BIN not set)"
endif

with_image: all
	${ZOS_PATH}/tools/pack.py ${IMG} ${FILES_IN_IMG}

clean:
	rm -rf build/ $(IMG)
