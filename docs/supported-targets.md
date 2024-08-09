## Relation with the kernel

The Zeal 8-bit OS is based on two main components: a kernel and a target code.
The kernel alone does nothing. The target needs to implement the drivers, some MMU macros used inside the kernel and a linker script. The linker script is fairly simple, it lists the sections in the order they must be linked in the final binary by `z80asm` assembler.

The kernel currently uses the following sections, which must be included in any linker script:

* `RST_VECTORS`: contains the reset vectors
* `SYSCALL_TABLE`: contains a table where syscall `i` routine address is stored at index `i`, must be aligned on 256
* `SYSCALL_ROUTINES`: contains the syscall dispatcher, called from a reset vector
* `KERNEL_TEXT`: contains the kernel code
* `KERNEL_STRLIB`: contains the string-related routines used in the kernel
* `KERNEL_DRV_VECTORS`: represents an array of drivers to initialize, check [Driver section](details/drivers.md) for more details.
* `KERNEL_BSS`: contains the data used by the kernel code, **must** be in RAM
* `DRIVER_BSS`: not used directly by the kernel, it shall be defined and used in the drivers. The kernel will set it to 0s on boot, it must be bigger than 2 bytes

## Zeal 8-bit Computer

As said previously, *Zeal 8-bit Computer* support is still partial but enough to have a command line program running. The romdisk is created before the kernel builds, this is done in the `script.sh` specified in the `target/zeal8bit/unit.mk`.

That script will compile the `init.bin` program and embed it inside a romdisk that will be concatenated to the compiled OS binary. The final binary can be directly flashed to the NOR Flash.

What still needs to be implemented, in no particular order:

* <s>UART driver</s> **Done**
* <s>I2C driver</s> **Done**
  * <s>EEPROM driver</s>
  * <s>RTC driver</s>
* Video API
  * <s>Text mode</s> **Done** (ABI/API implemented)
  * Graphic mode
* GPIO user interface/API
* Sound support
* Hardware timers, based on V-blank and H-blank signals
* *SD card support* (Not implemented in hardware yet)

## TRS-80 Model-I

A quick port to TRS-80 Model-I computer has been made to show how to port and configure Zeal 8-bit OS to targets that don't have an MMU.

This port is rather simple as it simply shows the boot banner on screen, nothing more. To do so, only a video driver for text mode is implemented.

To have a more interesting port, the following features would need to be implemented:

* Keyboard
* A disk to store the `init.bin`/romdisk, can be read-only, so can be stored on the ROM
* A read-write disk to store data, can be a floppy disk driver using ZealFS filesystem

## Agon Light

A port to the eZ80 powered Agon Light, written and maintained by [Shawn Sijnstra](https://github.com/sijnstra/Zeal-8-bit-OS). Feel free to use that fork for Agon specific bugs/requests. This uses the non-MMU kernel, and implements most of the features that the Zeal 8-bit computer implementation supports.

This port requires a loader for the binary to be stored and executed from the correct location. The binary is [OSbootZ, available here.](https://github.com/sijnstra/agon-projects/tree/main/OSbootZ)

Note that the port uses terminal mode to simplify keyboard I/O. This also means that the date function is not available.

Other notable features:

* Timed interrupts are used from the VBLANK timer, assumed to be 60Hz
* Coloured text is supported, using ANSI compatible control codes
* Keyboard input is supported in cooked and raw mode (as best as can be done in terminal mode)
* ROMDISK is supported and mounted Read-Only
* A ZealFS image for read/write can be loaded into memory and later (after reboot to MOS) saved back to SDCard

## Porting to another machine

To port Zeal 8-bit OS MMU version to another machine, make sure you have a memory mapper first that divides the Z80's 64KB address space into 4 pages of 16KB for the MMU version.

To port no-MMU Zeal 8-bit OS, make sure RAM is available from virtual address `0x4000` and above. The most ideal case being having ROM is the first 16KB for the OS and RAM in the remaining 48KB for the user programs and kernel RAM.

If your target is compatible, follow the instructions:

* Open the `Kconfig` file at the root of this repo, and add an entry to the `config TARGET` and `config COMPILATION_TARGET` options. Take the ones already present as examples.
* Create a new directory in `target/` for your target, the name **must** be the same as the one specified in the new `config TARGET` option.
* Inside this new directory, create a new `unit.mk` file. This is the file that shall contain all the source files to assemble or the ones to include.
* Populate your `unit.mk` file, to do so, you can populate the following `make` variables:
  * `SRCS`: list of the files to be assembled. Typically, these are the drivers (mandatory)
  * `INCLUDES`: the directories containing header files that can be included
  * `PRECMD`: a bash command to be executed **before** the kernel starts building
  * `POSTCMD`: a bash command to be executed **after** the kernel finishes building
* Create the assembly code that implements the drivers for the target
* Create an `mmu_h.asm` file which will be included by the kernel to configure and use the MMU. Check the file [`target/zeal8bit/include/mmu_h.asm`](https://github.com/Zeal8bit/Zeal-8-bit-OS/tree/main/target/zeal8bit/include/mmu_h.asm) to see how it should look like.
* Make sure to have at least one driver that mounts a disk, with the routine `zos_disks_mount`, containing an `init.bin` file, loaded and executed by the kernel on boot.
* Make sure to have at least one driver which registers itself as the standard out (stdout) with the routine `zos_vfs_set_stdout`.
