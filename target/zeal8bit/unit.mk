INCLUDES := ./ ./include

# Let's make zeal8bit target compatible with no-mmu. It will still use the MMU but the kernel will not be
# aware of it, it will only be used within the drivers
ifdef CONFIG_KERNEL_TARGET_HAS_MMU
	MMU_FILE = mmu.asm
endif

STAT_BYTES = stat
ifeq ($(detected_OS),Darwin)
	STAT_BYTES += -f %z
# TODO: Support Windows?
else
	STAT_BYTES += -c %s
endif

# Add the source files that are common to MMU and no-MMU configuration
SRCS := pio.asm i2c.asm keyboard.asm romdisk.asm $(MMU_FILE) interrupt_vect.asm eeprom.asm

ifdef CONFIG_TARGET_KEYBOARD_PS2
	SRCS += keyboard/ps2.asm
else
	SRCS += keyboard/parl.asm
endif

# Add the suffix "_romdisk" to the full binary name
FULLBIN_W_ROMDISK = $(basename $(FULLBIN))_with_romdisk.img

# If the UART is configured as the standard output, it shall be the first driver to initialize
ifdef CONFIG_TARGET_STDOUT_UART
	SRCS := uart.asm $(SRCS)
else
	SRCS += uart.asm
endif

# Same goes for the video driver
ifdef CONFIG_TARGET_STDOUT_VIDEO
	SRCS := video.asm $(SRCS)
else
	# Check if it was even activated in the menuconfig
	ifdef CONFIG_TARGET_ENABLE_VIDEO
		SRCS += video.asm
	endif
endif

ifdef CONFIG_TARGET_ENABLE_COMPACTFLASH
	SRCS += compactflash.asm
endif

ifdef CONFIG_TARGET_ENABLE_TFCARD
	SRCS += tf.asm
endif

# Command to be executed before compiling the whole OS.
# In our case, compile the programs that will be part of ROMDISK and create it.
# After creation, get its size, thanks to `stat` command, and store it in a generated header file
# named `romdisk_info_h.asm`
PRECMD := echo "Detected $(detected_OS) - $(STAT_BYTES)" && \
          (cd $(ZOS_PATH)/romdisk && make with_image) && \
          SIZE=$$($(STAT_BYTES) $(ZOS_PATH)/romdisk/disk.img) && \
          (echo -e "IFNDEF ROMDISK_H\nDEFINE ROMDISK_H\nDEFC ROMDISK_SIZE=$$SIZE\nENDIF" > $(PWD)/include/romdisk_info_h.asm) && \
          unset SIZE

# After compiling the whole OS, we need to remove the unnecessary binaries:
# In our case, it's the binary containing BSS addresses, so we only have to keep
# the one containing the actual code. The filename comes from the linker's first
# section name: RST_VECTORS
# FULLBIN defines the expected final binary path/name.
# After selecting the right binary, we have to truncate it to a size that will let us
# easily concatenate the ROMDISK after it.
# Of course, the final step is to concatenate the ROMDISK to the final binary after that.
POSTCMD := @echo "RAM used by kernel: $$($(STAT_BYTES)  $(BINDIR)/*KERNEL_BSS*.bin) bytes" && \
           rm $(BINDIR)/*KERNEL_BSS*.bin && \
           echo "OS size: $$($(STAT_BYTES)  $(FULLBIN)) bytes" && \
           cp $(FULLBIN) $(FULLBIN_W_ROMDISK) && \
           truncate -s $$(( $(CONFIG_ROMDISK_OFFSET_PAGES) * 0x4000 )) $(FULLBIN_W_ROMDISK) && \
           cat $(ZOS_PATH)/romdisk/disk.img >> $(FULLBIN_W_ROMDISK) && \
           echo "Image size: $$($(STAT_BYTES) $(FULLBIN_W_ROMDISK)) bytes"
