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
FULLBIN=$(BINDIR)/$(BIN)
MAPFILE=os.map
# Sources related
LINKERFILE := linker.asm
MKFILE := unit.mk # Name of the makefile in the components/units
ASMFLAGS := -Iinclude/
INCLUDEDIRS:=
PRECMD :=
POSTCMD :=

# Before including the Makefiles, include the configuration one if it exists
-include $(KCONFIG_CONFIG)

# Define the TARGET as a make variable. In other words, remove the quotes which surround
# it.
TARGET=$(shell echo $(CONFIG_TARGET))

# Include all the Makefiles in the different directories
# Parameters:
#	- $1: makefile to include
#	- $2: Variable name where SRCS will be appended
#	- $3: Variable name where INCLUDES will be appended
#	- $4: Variable name where PRECMD will be appended
#	- $5: Variable name where POSTCMD will be appended
define IMPORT_unitmk =
    SRCS :=
    INCLUDES :=
    PWD := $$(dir $1)
    include $1
    CURRENTDIR := $$(shell basename $$(dir $1))/
    $2 := $$($2) $$(addprefix $$(CURRENTDIR),$$(SRCS))
    $3 := $$($3) $$(addprefix $$(CURRENTDIR),$$(INCLUDES))
    $4 := $$($4) $$(PRECMD)
    $5 := $$($5) $$(POSTCMD)
endef

# Parameters:
#	- $1: Variable name where SRCS will be stored
#	- $2: Variable name where INCLUDES will be stored
#   - $3: Variable name where PRECMD will be stored
#   - $4: Variable name where POSTCMD will be stored
define IMPORT_subunitmk = 
    SUBMKFILE = $$(wildcard */$$(MKFILE))
    TMP1 :=
    TMP2 :=
    TMP3 :=
    TMP4 :=
    $$(foreach file,$$(SUBMKFILE),$$(eval $$(call IMPORT_unitmk,$$(file),TMP1,TMP2,TMP3,TMP4)))
    $1 := $$(TMP1)
    $2 := $$(TMP2)
    $3 := $$(TMP3)
    $4 := $$(TMP4)
endef

$(eval $(call IMPORT_subunitmk,ASMSRCS,INCLUDEDIRS,PRECMD,POSTCMD))
#$(info "ASMSRCS = $(ASMSRCS), INCLUDES = "$(INCLUDEDIRS), PRECMD = $(PRECMD), POSTCMD = $(POSTCMD)")

# Generate the .o files out of the .c files
OBJS = $(patsubst %.asm,%.o,$(ASMSRCS))
# Same but with build dir prefix
BUILTOBJS = $(addprefix $(BINDIR)/,$(OBJS))

# We have to manually do it for the linker script
LINKERFILE_PATH=target/$(TARGET)/$(LINKERFILE)
LINKERFILE_OBJ=$(patsubst %.asm,%.o,$(LINKERFILE_PATH))
LINKERFILE_BUILT=$(BINDIR)/$(LINKERFILE_OBJ)

.PHONY: check menuconfig $(SUBDIRS) version

all: version precmd $(KCONFIG_CONFIG) $(LINKERFILE_OBJ) $(OBJS)
	$(CC) -o$(BINDIR)/$(BIN) -b -m -s $(LINKERFILE_BUILT) $(BUILTOBJS)
	@#$(PYTHON) merge_bin.py $(BINDIR)/$(MAPFILE) $(BINDIR)/$(BIN)
	@echo "Executing post commands..."
	$(POSTCMD)


    # Generate a version file that will be used as a boilerplate
    # when the system starts
version:
	@echo ZealOS `git describe --tags` > version.txt
	@echo Build time: `date +"%Y-%m-%d %H:%M"` >> version.txt

precmd:
	@echo "Executing pre commands..."
	@$(PRECMD)

# Check if configuration file exists  
$(KCONFIG_CONFIG):
	@test -e $@ || { echo "Configuration file $@ could not be found. Please run make menuconfig first"; exit 1; }

%.o: %.asm
	$(CC) $(ASMFLAGS) $(addprefix -I,$(INCLUDEDIRS)) -O$(BINDIR) $<

check:
	@python3 --version > /dev/null || (echo "Cannot find python3 binary, please install it and retry")
	@pip3 --version > /dev/null || (echo "Cannot find pip3 binary, please install it and retry" && exit 1)
	@pip3 list | grep kconfiglib3 > /dev/null || (echo -e "Cannot find kconfiglib python package, please install it with:\npip3 install kconfiglib" && exit 1)

# Check where pip installs binaries, concatenate bin/ folder
# and execute the menuconfig script.
# Afterwards, the .config file is converted to a .asm file, that can be included
# inside any ASM source file.
# Note: DEFC cannot define a string like DEFC test = "test" for some reason.
# Thus, strings must be encoded as macros:
# MACRO CONFIG_OPTION_NAME
#    DEFM "test", 0
# ENDM
define CONVERT_config_asm =
    cat $1 | \
    grep "^CONFIG_" | \
    sed 's/=y/=1/g' | sed 's/=n/=0/g' | \
    sed 's/\(.*\)=\(".*"\)/MACRO \1\n    DEFM \2\nENDM/g' | \
    sed 's/^CONFIG/DEFC CONFIG/g' > $2
endef

menuconfig:
	$(PYTHON) $(shell $(PYTHON) -m site --user-base)/bin/menuconfig
	@echo "Converting $(KCONFIG_CONFIG) to $(OSCONFIG_ASM) ..."
	@$(call CONVERT_config_asm,$(KCONFIG_CONFIG), $(OSCONFIG_ASM))

prepare_dirs:
	@mkdir -p $(BINDIR)

dump:
	$(DISASSEMBLER) -x $(BINDIR)/os.map $(BINDIR)/$(BIN) | less

fdump:
	$(DISASSEMBLER) -x $(BINDIR)/os.map $(BINDIR)/$(BIN) > $(BINDIR)/os.dump

clean:
	rm -rf $(OSCONFIG_ASM) *.bin *.o *.map *.sym $(BINDIR) 
