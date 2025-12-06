INCLUDES := ./ ./include

# Compile all assembly files in eZ80 mode
ASMFLAGS += -mez80_z80

# Add the source files to assemble for current target
SRCS := uart.asm pio.asm romdisk.asm ram1disk.asm interrupt_vect.asm

# Add the suffix "_romdisk" to the full binary name
FULLBIN_W_ROMDISK = $(basename $(FULLBIN))_with_romdisk.img

DISK_PATH := $(ZOS_PATH)/romdisk/init/disk.img
INIT_PATH := $(if $(CONFIG_ROMDISK_INCLUDE_INIT_BIN),$(ZOS_PATH)/romdisk/init/build/init.bin,)

# Undefine CONFIG_ROMDISK_EXTRA_FILES if it is empty
ifeq ($(CONFIG_ROMDISK_EXTRA_FILES),"")
    undefine CONFIG_ROMDISK_EXTRA_FILES
endif

# Command to be executed before compiling the whole OS.
ifdef CONFIG_ENABLE_ROMDISK
PRECMD := @echo "Compiling for Agon Light!" && \
          $(if $(CONFIG_ROMDISK_INCLUDE_INIT_BIN),(cd $(ZOS_PATH)/romdisk/init && make) &&) \
		  ${ZOS_PATH}/tools/pack.py $(DISK_PATH) $(INIT_PATH) $(CONFIG_ROMDISK_EXTRA_FILES) $(EXTRA_ROMDISK_FILES) $(EXTRA_ROMDISK_FILES) && \
          SIZE=$$(stat -c %s $(ZOS_PATH)/romdisk/disk.img) && \
          (echo -e "IFNDEF ROMDISK_H\nDEFINE ROMDISK_H\nDEFC ROMDISK_SIZE=$$SIZE\nENDIF" > $(PWD)/include/romdisk_info_h.asm) && \
          unset SIZE

# After compiling the whole OS, we need to remove the unnecessary binaries:
# In our case, it's the binary containing BSS addresses, so we only have to keep
# the one containing the actual code. The filename comes from the linker's first
# section name: RST_VECTORS
# We can do more, like generate a single image that has the romdisk, check zeal8bit/unit.mk for this
# FULLBIN defines the expected final binary path/name.
# After selecting the right binary, we have to truncate it to a size that will let us
# easily concatenate the ROMDISK after it. In the case of Agon this is on a 64K boundary.
# Of course, the final step is to concatenate the ROMDISK to the final binary after that.
POSTCMD := @echo "RAM used by kernel: $$(du -bs $(BINDIR)/*KERNEL_BSS*.bin | cut -f1) bytes" && \
           rm $(BINDIR)/*KERNEL_BSS*.bin && \
           echo "OS size: $$(du -bs $(FULLBIN) | cut -f1) bytes" && \
           cp $(FULLBIN) $(FULLBIN_W_ROMDISK) && \
           truncate -s 64K $(FULLBIN_W_ROMDISK) && \
           cat $(DISK_PATH) >> $(FULLBIN_W_ROMDISK) && \
           echo "Image size: $$(du -bs $(FULLBIN_W_ROMDISK) | cut -f1) bytes"
endif