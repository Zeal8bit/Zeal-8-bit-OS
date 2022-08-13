# Set the binaries
SHELL := /bin/bash
CC=z80asm
DISASSEMBLER=z88dk-dis
PYTHON=python3
# Menuconfig-related env variables
export KCONFIG_CONFIG = os.conf
export MENUCONFIG_STYLE = aquatic
export OSCONFIG_ASM = include/osconfig.asm
# Output related
BIN=os.bin
BINDIR=build
MAPFILE=os.map
# Sources related
LINKERFILE := linker.asm
MKFILE := unit.mk		 # Name of the makefile in the components/units
ASMFLAGS :=
ASMSRCS:=
INCLUDEDIRS:= include/
SUBMKFILE = $(wildcard */$(MKFILE)) # List all sub MKFILE

# Before including the Makefiles, include the configuration one if it exists
-include $(KCONFIG_CONFIG)

# Include all the Makefiles in the different directories
define IMPORT_unitmk =
 include $1
 ASMSRCS += $$(addprefix $$(dir $(1)),$$(SRCS))
 INCLUDEDIRS += $$(addprefix -I$$(dir $(1)),$$(INCLUDES))
endef

$(foreach file,$(SUBMKFILE),$(eval $(call IMPORT_unitmk,$(file))))

# Generate the .o files out of the .c files
OBJS = $(patsubst %.asm,%.o,$(ASMSRCS))
# Same but with build dir prefix
BUILTOBJS = $(addprefix $(BINDIR)/,$(OBJS))

# We have to manually do it for the linker script
 LINKERFILE_OBJ=$(patsubst %.asm,%.o,$(LINKERFILE))
 LINKERFILE_BUILT=$(addprefix $(BINDIR)/,$(LINKERFILE_OBJ))

.PHONY: check menuconfig $(SUBDIRS)

all: $(KCONFIG_CONFIG) $(LINKERFILE_OBJ) $(OBJS)
	$(CC) -b -m -s $(LINKERFILE_BUILT) $(BUILTOBJS)
	#$(PYTHON) merge_bin.py $(BINDIR)/$(MAPFILE) $(BINDIR)/$(BIN)

# Check if configuration file exists  
$(KCONFIG_CONFIG):
	@test -e $@ || { echo "Configuration file $@ could not be found. Please run make menuconfig first"; exit 1; }

%.o: %.asm
	$(CC) $(ASMFLAGS) -I$(INCLUDEDIRS) -O$(BINDIR) $<

check:
	@python3 --version > /dev/null || (echo "Cannot find python3 binary, please install it and retry")
	@pip3 --version > /dev/null || (echo "Cannot find pip3 binary, please install it and retry" && exit 1)
	@pip3 list | grep kconfiglib3 > /dev/null || (echo -e "Cannot find kconfiglib python package, please install it with:\npip3 install kconfiglib" && exit 1)

# Check where pip installs binaries, concatenate bin/ folder
# and execute the menuconfig script.
# Afterwards, the .config file is converted to a .asm file, that can be included
# inside any ASM source file
define CONVERT_config_asm =
    cat $1 | \
    grep "^CONFIG_" | \
    sed 's/=y/=1/g' | sed 's/=n/=0/g' | \
    sed 's/^/DEFC /g' > $2
endef

menuconfig:
	$(PYTHON) $(shell $(PYTHON) -m site --user-base)/bin/menuconfig
	@echo "Converting $(KCONFIG_CONFIG) to $(OSCONFIG_ASM) ..."
	@$(call CONVERT_config_asm,$(KCONFIG_CONFIG), $(OSCONFIG_ASM))

prepare_dirs:
	@mkdir -p $(BINDIR)

dump:
	$(DISASSEMBLER) -x $(BINDIR)/core/boot.map $(BINDIR)/$(BIN) | less

clean:
	rm -rf $(OSCONFIG_ASM) *.bin *.o *.map *.sym $(BINDIR) 
