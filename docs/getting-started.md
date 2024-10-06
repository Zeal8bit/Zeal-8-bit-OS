# Getting started

## Requirements

At the moment, the project has only been assembled on Linux (Ubuntu 20.04 and 22.04), it should be compatible with Mac OS and Windows as long as you have:

* bash
* git (to clone this repo)
* make
* python3 with pip3. Used for the `menuconfig`.
* z88dk v2.2 (or later). Only its assembler, `z80asm`, is strictly required. The latest version of `z80asm` must be used as earlier versions don't have support for `MACRO`.

On Ubuntu, the following commands can be used to install the dependencies. They must be run as a user, not root!
```
sudo apt update
sudo apt install git python3 python3-pip
pip3 install --ignore-installed --user kconfiglib
```

For installing Z88DK, please [check out their Github project](https://github.com/z88dk/z88dk).

## Configuring Zeal 8-bit OS

After installing the dependencies listed above and cloning this repository, the first thing to do is to configure the OS. To do so, simply execute:

```
make menuconfig
```

From there, it is possible to configure the kernel but also the target computer's options, for example for *Zeal 8-bit computer*, it is possible to configure where the romdisk (more about this below) will be located on the ROM.

All the options have default values, so, if you have nothing to modify in particular or you are not sure what you are doing, press `S` to save the current (default) configuration. The filename for the configuration will be asked, keep it as `os.conf` and press enter.

To exit the menuconfig, press `Q` key.

Or you can also run following command instead to use the default config:

```
make alldefconfig
```

If everything goes well, the following message will be shown:

```
Converting os.conf to include/osconfig.asm ...
```

## Building

To build the OS (kernel + driver + target configuration), use the command:
```
make
```

After compiling, you should see the line:
```
OS binary: build/os.bin
```

Indicating that the final binary has been created. This binary only includes the kernel code and the drivers.

The file named `os_with_romdisk.img` contains the OS binary with the generated `romdisk` (more about this below)

It is possible to embed any file inside the `romdisk` before compiling the OS thanks to the environment variable `EXTRA_ROMDISK_FILES`. This variable must be set with a list of absolute paths to the files to embed, for example, if you want to embed the files `/home/me/documents/file.txt` and `/home/me/dev/mygame.bin` inside the romdisk, you can set the environment variable as follows:

```
export EXTRA_ROMDISK_FILES="/home/me/documents/file.txt /home/me/dev/mygame.bin"
```

After that, it is required to recompile the OS, with `make`, to build the romdisk image again. The logs will show the files that will be part of the romdisk:

```
...
Packing the files
pack disk.img build/init.bin simple.txt /home/me/documents/file.txt /home/me/dev/mygame.bin
```

## Flashing

### Zeal 8-bit Computer

On Zeal 8-bit Computer, the file to flash is `os_with_romdisk.img` as it also contains the initial program that is executed after the OS finishes booting.

To flash this file, you can use Zeal 8-bit Bootloader if your board is equipped with it. Check the [bootloader repository](https://github.com/Zeal8bit/Zeal-Bootloader) for more info about it.

Or, you can flash it directly on the 256KB NOR Flash, referenced SST39SF020, thanks to an external flasher, such as the TL866. In that case, you can use [minipro](https://gitlab.com/DavidGriffith/minipro/) program and the following command:
```
minipro -w -S -p sst39sf020 build/os_with_romdisk.img
```

### Generic targets

The binary can be directly flashed to a ROM, to a NOR flash, or any other storage the target computer is using. It can also be used to boot an emulator.

For example, to flash it on a W27C020 (256KB) EEPROM, you can still use a TL866xx programmer with [minipro](https://gitlab.com/DavidGriffith/minipro/) and the following command:

```
minipro -w -S -p w27c020 build/os_with_romdisk.img
```

Of course, this is completely dependent on the target computer.
