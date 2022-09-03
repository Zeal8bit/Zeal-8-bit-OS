INCLUDES := ./ ./include
# Load the video driver first, in order to get an output early on
SRCS := video.asm pio.asm keyboard.asm romdisk.asm interrupt_vect.asm
	# Command to be executed before compiling the whole OS.
	# In our case, compile the programs taht will be part of ROMDISK and create it.
PRECMD := (cd $(PWD)/romdisk ; ./create.sh)
	# After compiling the whole OS, we need to remove the unecessary binaries:
	# In our case, it's the binary containing BSS addresses, so we only have to keep
	# the one containing the actual code. The filename comes from the linker's first
	# section name: RST_VECTORS
	# FULLBIN defines the expected final binary path/name.
	# After selecting the rigth binary, we have to truncate it to a size that will let us
	# easily concatenate the ROMDISK after it.
	# Of course, the final step is to concatenate the ROMDISK to the final binary after that.
POSTCMD := @echo "RAM used by kernel: $$(du -bs $(BINDIR)/*KERNEL_BSS*.bin | cut -f1) bytes" && \
	   rm $(BINDIR)/*KERNEL_BSS*.bin && mv $(BINDIR)/*RST_VECTORS*.bin $(FULLBIN) && \
	   echo "OS size: $$(du -bs $(FULLBIN) | cut -f1) bytes" && \
	   truncate -s $$(($(CONFIG_ROMDISK_ADDRESS))) $(FULLBIN) && \
	   cat $(PWD)/romdisk/disk.img >> $(FULLBIN)