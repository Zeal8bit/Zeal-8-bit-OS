INCLUDES := ./ ./include

# Compile all assembly files in eZ80 mode
ASMFLAGS += -mez80_z80

# Add the source files to assemble for current target
SRCS := uart.asm pio.asm romdisk.asm interrupt_vect.asm ram1disk.asm

# Add the suffix "_romdisk" to the full binary name
FULLBIN_W_ROMDISK = $(basename $(FULLBIN))_with_romdisk.img

# Command to be executed before compiling the whole OS.
PRECMD := @echo "Compiling for Agon Light!" && \
          (cd $(ZOS_PATH)/romdisk && make) && \
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
           cat $(ZOS_PATH)/romdisk/disk.img >> $(FULLBIN_W_ROMDISK) && \
           echo "Image size: $$(du -bs $(FULLBIN_W_ROMDISK) | cut -f1) bytes"

