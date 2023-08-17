## TRS-80 Model-I target

This target is an example of how to port Zeal 8-bit OS to a computer that doesn't have a memory mapper/MMU with the 4x16KB virtual pages.

### Build for TRS-80 Model-I

To build Zeal 8-bit OS for the TRS-80 model one, follow these instructions:
* Use `make menuconfig` at the root of this project
* Choose `TRS-80 Model-I` in `Target board` menu
* Press *Backspace* to go back to the main menu of `menuconfig`
* Enter `Kernel configuration` menu
* Choose the addresses for `Kernel stack virtual address` and `Kernel RAM start address` according to the available RAM on your machine. These constants will ark the beginning and the end of the Kernel usable RAM respectively. For example, if you have 64KB of RAM, you can choose `0xFFFF` and `0xC000` respectively, as such the user programs will have 32KB of memory, from `0x4000` to `0xC000`. If you have 32KB of RAM, you can choose `0xBFFF` and `0x8000` respectively.
* Press `s` to save the configuration file as `os.conf`
* Press `q` to exit the `menuconfig`
* Type `make`

The OS should start building and show the follow lines once done:
```
Executing post commands...
RAM used by kernel: 929 bytes
```

The file `build/os.bin` is the one to use as a ROM for the TRS-80.


> Note
>
> In the steps above, the allocated kernel RAM size is 16KB. In practice, this depends on the target implementation. Allocating 1KB for the kernel stack is enough, the TRS-80 video driver uses less than 8 bytes at the moment, so allocating 1KB or 2KB is already enough. Check the `README.md` file at the root of this repo for more information about kernel RAM.

### Executing the OS

This was tested with `trs80gp` emulator, the following command line can be used to execute the OS:
```
trs80gp -m1 -rom build/os.bin
```

### Supported drivers

At the moment, only a text mode video driver has been implemented, as the main goal is to show how to implement a simple MMU-less target for Zeal 8-bit OS.

For more information about the other drivers (UART, keyboard, PIO, etc...) and their API, check the `target/zeal8bit` directory.