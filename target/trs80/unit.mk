INCLUDES := ./ ./include

# Add the source files to assemble for current target, we only have a video driver for now
SRCS := video.asm

# Command to be executed before compiling the whole OS, let's print a small message
PRECMD := @echo "Compiling for TRS-80!"

# After compiling the whole OS, we need to remove the unnecessary binary. In our case, it's the binary
# containing BSS addresses, so we only have to keep the one containing the actual code. The filename
# comes from the linker's first section name: RST_VECTORS
# We can do more, like generate a single image that has the romdisk, check `zeal8bit/unit.mk` for this.
POSTCMD := @echo "RAM used by kernel: $$(du -bs $(BINDIR)/*KERNEL_BSS*.bin | cut -f1) bytes" && \
           rm $(BINDIR)/*KERNEL_BSS*.bin
