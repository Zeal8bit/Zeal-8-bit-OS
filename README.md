<p align="center">
    <img src="md_images/zeal8bitos.png" alt="Zeal 8-bit OS logo" />
</p>
<p align="center">
    <a href="https://opensource.org/licenses/Apache-2.0">
        <img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg" alt="Licence" />
    </a>
    <p align="center">A simple and portable Operating System for Z80-based computers, written entirely in Z80 assembly.</p>
    <p align="center"><a href="https://www.youtube.com/watch?v=5jTcWRN8IbA">Click here to have a look at the video presentation of the project on Youtube</a></p>
</p>

## Table of Contents
- [About the project](#about-the-project)
  - [What?](#what)
  - [Why?](#why)
  - [Yet another OS?](#yet-another-os)
  - [Overview](#overview)
- [Getting started](#getting-started)
  - [Requirements](#requirements)
  - [Configuring Zeal 8-bit OS](#configuring-zeal-8-bit-os)
  - [Building](#building)
  - [Flashing](#flashing)
    - [Zeal 8-bit Computer](#zeal-8-bit-computer)
    - [Generic targets](#generic-targets)
- [Features Overview](#features-overview)
- [TO DO](#to-do)
- [Implementation details](#implementation-details)
  - [Memory Mapping](#memory-mapping)
    - [Kernel configured with MMU](#kernel-configured-with-mmu)
    - [Kernel configured as no-MMU](#kernel-configured-as-no-mmu)
  - [Kernel](#kernel)
    - [Used registers](#used-registers)
    - [Reset vectors](#reset-vectors)
  - [User space](#user-space)
    - [Entry point](#entry-point)
    - [Program parameters](#program-parameters)
  - [Syscalls](#syscalls)
    - [Syscall table](#syscall-table)
    - [Syscall parameters](#syscall-parameters)
    - [Syscall parameters constraints](#syscall-parameters-constraints)
    - [Syscall `exec`](#syscall-exec)
    - [Syscall documentation](#syscall-documentation)
  - [Drivers](#drivers)
  - [Virtual File System](#virtual-file-system)
    - [Architecture of the VFS](#architecture-of-the-vfs)
  - [Disks](#disks)
  - [File systems](#file-systems)
- [Supported targets](#supported-targets)
  - [Relation with the kernel](#relation-with-the-kernel)
  - [Zeal 8-bit Computer](#zeal-8-bit-computer-1)
  - [TRS-80 Model-I](#trs-80-model-i)
  - [Agon Light](#agon-light)
  - [Porting to another machine](#porting-to-another-machine)
- [Version History](#version-history)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

# About the project

## What?

Zeal 8-bit OS is an operating system written entirely in Z80 assembly for Z80 computers. It has been designed around simplicity and portability. It is inspired by Linux and CP/M. It has the concept of drivers and disks while being ROM-able.

## Why?

As you may know, this project is in fact part of a bigger project called *Zeal 8-bit Computer*, which, as its name states, consists of an entirely newly designed 8-bit computer. It is based on a Z80 CPU.

When writing software, demos or drivers for it, I realized the code was tied to *Zeal 8-bit computer* hardware implementation, making them highly incompatible with any other Z80 computers, even if the required features were basic (only UART for example).

## Yet another OS?

Well, it's true that there are several (good) OS for the Z80 already such as SymbOS, Fuzix or even CP/M, but I wanted something less sophisticated:
not multithreaded, ROM-able, modular and configurable.
The goal is to have a small and concise ABI that lets us write software that can communicate with the hardware easily and with the least hardcoded behaviors.

While browsing the implementation details or this documentation, you will notice that some aspects are similar to Linux kernel, such as the syscall names or the way opened files and drivers are handled. Indeed, it was a great source of inspiration, but as it is a 32-bit only system, written in C, only the APIs/interfaces have been inspiring.

If you are familiar with Linux ABI/interface/system programming, then Zeal 8-bit OS will sound familiar!

## Overview

Currently, once compiled, the kernel itself takes less than 8KB of ROM (code), and less than 1KB of RAM (data).
Of course, this is highly dependent on the configuration. For example, increasing the maximum number of opened files, or the maximum length of paths will increase the size of the space used for data.

This size will increase as soon as more features will be implemented, for example when there will be more file systems. However, keep in mind that while writing the code, speed was more important than code size. In fact, nowadays, read-only memories are available in huge sizes and at a fair price.

Moreover, the OS can still be optimized in both speed and size. This is not the current priority but it means that we can still make it better! (as always)

To the kernel size, we have to add the drivers implementation size and the RAM used by them. Of course, this is highly dependent on the target machine itself, the features that are implemented and the amount of drivers we have.

The OS is designed to work with an MMU, thus, the target must have 4 swappable virtual pages of 16KB each. The pages must be interchangeable. More info about it in the [Memory Mapping](#memory-mapping) section.


# Getting started

## Requirements

At the moment, the project has only been assembled on Linux (Ubuntu 20.04 and 22.04), it should be compatible with Mac OS and Windows as long as you have:

* bash
* git (to clone this repo)
* make (GNU Make 4+)
* python3 with pip3. Used for the `menuconfig`.
* z88dk v2.2 (or later). Only its assembler, `z80asm`, is strictly required. The latest version of `z80asm` must be used as earlier versions don't have support for `MACRO`.

On Ubuntu, the following commands can be used to install the dependencies. They must be run as a user, not root!
```
sudo apt update
sudo apt install git python3 python3-pip
pip3 install --ignore-installed --user kconfiglib
```

On MacOS, the following commands can be used to install the dependencies.
```
brew install make
brew install binutils
```

For installing Z88DK, please [check out their Github project](https://github.com/z88dk/z88dk).

### Darwin / MacOS Requirements

> [!IMPORTANT]
> Use `gmake` instead of `make` whenever instructed to use `make` throughout.

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

# Features Overview

The kernel itself supports the following features:
* Mono-threaded system, the whole CPU is dedicated to running a single program!
* Up to 26 disks (A to Z)
* Files
* Directories
* Drivers
* Abstract opened "dev" which can represent an opened file, directory, or driver
* Real-Time Clock
* Timer (can be hardware or software timer)
* Up to 16MB physical address space divided as 256 banks of 16KB (for MMU kernel)
* Open, read, write seek, close, ioctl drivers
* Open, read, write, seek, close, remove files
* Open, browse, close, remove directories
* Load raw binaries as init file. No dynamic relocation yet
* Syscalls to perform communication between user programs and kernel
* File systems ("rawtable" and ZealFS implemented yet)
* Modular build system, simplifying adding files and targets to the compilation

The only supported target at the moment is *Zeal 8-bit computer*, the port is not complete yet, the implemented features are:
* Video 640x480 text-mode
* UART as video card replacement (text mode)
* UART for sending and receiving data
* MMU and no-MMU build, configurable in the `menuconfig`
* PS/2 keyboard
* I2C
* EEPROM (I2C)
* GPIO (partial)
* Free space in ROM used as a read-only `romdisk`, storing `init.bin` binary
* Linker script

# TO DO

There is still some work to do on the project. Some features need to be developed on the kernel side, some things need to be documented in the project, here is a non-exhaustive list:
* <s>Generate header files usable by user programs for syscalls, file entries, directories entries, opening flags, etc...</s> **Done, header files are available in `kernel_headers` directory.**
* <s>Document clearly what each syscall does</s> **Done, check ASM header file.**
* <s>A writable file system. Currently, only `rawtable` (more about it below) file system is implemented, which is read-only.</s> **ZealFS file system has been implemented, it supports files and directories, and is writable!**
* <s>Make it work with MMU-less targets, and add a configuration option for this</s> **Done, kernel is now compatible with MMU-less targets!**
* Come up with ABI and API for video, TTY, GPIO drivers, etc...
  * <s>Keyboard API</s> **Done**
  * <s>Video text API</s> **Done**
  * GPIO API
  * Video graphic API
* Relocatable user programs. It is already possible to generate a relocation table when assembling a program with `z88dk-z80asm`.
* Refactor the kernel code to have a proper memory module, with better names for the required macros.
* Process all the `TODO` and `FIXME` left in the code.
* Lift some restrictions that can be avoided, such as having the user's program stack pointer in the last virtual page.
* List the loaded drivers from a user program.
* List the available disks from a user program.
* Implement a software breakpoint with a reset vector.
* Optimize the code to be smaller and faster.
* *More things I am forgetting...*

And of course, **fixing bugs!**

As Zeal 8-bit OS is still in beta version, you will encounter bugs, and errors, please feel free to open an issue, with a snippet of code to help reproduce it.

# Implementation details

In the sections below, the word "program", also referred to as "users programs", designates software being executed after the kernel loaded it from a file and jumped to it.

## Memory Mapping

### Kernel configured with MMU

Zeal 8-bit OS can separate kernel RAM and user programs thanks to virtual pages. Indeed, as it is currently implemented, the kernel is aware of 4 virtual pages of 16KB.

The first page, page 0, shall not be switched as it contains the kernel code. This means that the OS binary is limited to 16KB, it must never exceed this size. When a user's program is being executed, any `syscall` will result in jumping in the first bank where the OS code resides. So if this page is switched for another purpose, no syscall, no interrupt nor communication with the kernel must happen, else, undefined behavior will occur.

The second page, page 1, is where user programs are copied and executed. Thus, all the programs for Zeal 8-bit OS shall be linked from address `0x4000` (16KB). When loading a program, the second and third pages are also mapped to usable RAM from the user program. Thus, a user program can have a maximum size of 48KB.

The fourth page, page 3, is used to store the OS data for both the kernel and the drivers. When loading a user program, this page is switched to RAM, so that it's usable by the program, when a syscall occurs, it's switched back to the kernel RAM. Upon loading a user program, the SP (Stack Pointer) is set to `0xFFFF`. However, this may change in the near future.

To sum up, here is a diagram to show the usage of the memory:
<img src="md_images/mapping.svg" alt="Memory mapping diagram"/>

*If the user program's parameters are pointing to a portion of memory in page 3 (last page), there is a conflict as the kernel will always map its RAM page inside this exact same page during a syscall. Thus, it will remap user's page 3 into page 2 (third page) to access the program's parameters. Of course, in case the parameters are pointers, they will be modified to let them point to the new virtual address (in other words, a pointer will be subtracted by 16KB to let it point to page 2).

### Kernel configured as no-MMU

To be able to port Zeal 8-bit OS to Z80-based computers that don't have an MMU/Memory mapper organized as shown above, the kernel has a new mode that can be chosen through the `menuconfig`: no-MMU.

In this mode, the OS code is still expected to be mapped in the first 16KB of the memory, from `0x0000` to `0x3FFF` and the rest is expected to be RAM.

Ideally, 48KB of RAM should be mapped starting at `0x4000` and would go up to `0xFFFF`, but in practice, it is possible to configure the kernel to expect less than that. To do so, two entries in the `menuconfig` must be configured appropriately:

* `KERNEL_STACK_ADDR`: this marks the end of the kernel RAM area, and, as its name states, will be the bottom of the kernel stack.
* `KERNEL_RAM_START`: this marks the start address of the kernel RAM where the stack, all the variables used by the kernel AND drivers will be stored. Of course, it must be big enough to store all of these data. For information, the current kernel `BSS` section size is around 1KB. The stack depth depends on the target drivers' implementation. Allocating 1KB for the stack should be more than enough as long as no (big) buffers are stored on it. Overall allocating at least 3KB for the kernel RAM should be safe and future-proof.

To sum up, here is a diagram to show the usage of the memory:
<img src="md_images/mapping_nommu.svg" alt="Memory mapping diagram"/>

Regarding the user programs, the stack address will always be set to `KERNEL_RAM_START - 1` by the kernel before execution. It also corresponds to the address of its last byte available in its usable address space. This means that a program can determine the size of the available RAM by performing `SP - 0x4000`, which gives, in assembly:

```
ld hl, 0
add hl, sp
ld bc, -0x4000
add hl, bc
; HL contains the size of the available RAM for the program, which includes the program's code and its stack.
```

## Kernel

### Used registers

Z80 presents multiple general-purpose registers, not all of them are used in the kernel, here is the scope of each of them:

| Register           | Scope                          |
| ------------------ | ------------------------------ |
| AF, BC, DE, HL     | System & application           |
| AF', BC', DE', HL' | Interrupt handlers             |
| IX, IY             | Application (unused in the OS) |

This means that the OS won't alter IX and IY registers, so they can be used freely in the application.

The alternate registers (names followed by `'`) may only be used in the interrupt handlers[^1]. An application should not use these registers. If for some reason, you still have to use them, please consider disabling the interrupts during the time they are used:

```
my_routine:
                di              ; disable interrupt
                ex af, af'      ; exchange af with alternate af' registers
                [...]           ; use af'
                ex af, af'      ; exchange them back
                ei              ; re-enable interrupts
```

Keep in mind that disabling the interrupts for too long can be harmful as the system won't receive any signal from hardware (timers, keyboard, GPIOs...)

[^1]: They shall **not** be considered as non-volatile nonetheless. In other words, an interrupt handler shall not make the assumption that the data it wrote inside any alternate register will be kept until the next time it is called.

### Reset vectors

The Z80 provides 8 distinct reset vectors, as the system is meant to always be stored in the first virtual page of memory, these are all reserved for the OS:

Vector | Usage
------ | ------
$00 | Software reset
$08 | Syscall
$10 | Jumps to the address in HL (can be used for calling HL)
$18 | _Unused_
$20 | _Unused_
$28 | _Unused_
$30 | _Unused_
$38 | Reserved for Interrupt Mode 1, usable by the target implementation

## User space

### Entry point

When a user program is executed, the kernel allocates 3 pages of RAM (48KB), reads the binary file to execute and loads it starting at virtual address `0x4000` by default. This entry point virtual address is configurable through the `menuconfig` with option `KERNEL_INIT_EXECUTABLE_ADDR`, but keep in mind that existing programs won't work anymore without being recompiled because they are not relocatable at runtime.

### Program parameters

As described below, the `exec` syscall takes two parameters: a binary file name to execute and a parameter.

This parameter must be a NULL-terminated string that will be copied and transmitted to the binary to execute through registers `DE` and `BC`:

* `DE` contains the address of the string. This string will be copied to the new program's memory space, usually on top of the stack.
* `BC` contains the length of that string (so, excluding the NULL-byte). If `BC` is 0, `DE` **must** be discarded by the user program.

## Syscalls

The system relies on syscalls to perform requests between the user program and the kernel. Thus, this shall be the way to perform operations on the hardware. The possible operations are listed in the table below.

### Syscall table

Num  | Name | Param. 1 | Param. 2 | Param. 3
--------| ----- | --------| ---- | ----
0 | read | u8 dev | u16 buf | u16 size |
1 | write | u8 dev | u16 buf | u16 size |
2 | open | u16 name | u8 flags | |
3 | close | u8 dev | | |
4 | dstat | u8 dev | u16 dst | |
5 | stat | u16 name | u16 dst | |
6 | seek | u8 dev | u32 offset | u8 whence |
7 | ioctl | u8 dev | u8 cmd | u16 arg |
8 | mkdir | u16 path | | |
9 | chdir | u16 path | | |
10 | curdir | u16 path | | |
11 | opendir | u16 path | | |
12 | readdir | u8 dev | u16 dst | |
13 | rm | u16 path | | |
14 | mount | u8 dev | u8 letter | u8 fs |
15 | exit | u8 code | | |
16 | exec | u16 name | u16 argv | |
17 | dup | u8 dev | u8 ndev | |
18 | msleep | u16 duration | | |
19 | settime | u8 id | u16 time | |
20 | gettime | u8 id | u16 time | |
21 | setdate | u16 date | |
22 | getdate | u16 date | |
23 | map | u16 dst | u24 src | |
24 | swap | u8 dev | u8 ndev | |

Please check the [section below](#syscall-parameters) for more information about each of these call and their parameters.

**NOTE**: Some syscalls may be unimplemented. For example, on computers where directories are not supported,directories-related syscalls may be omitted.

### Syscall parameters

In order to perform a syscall, the operation number must be stored in register `L`, the parameters must be stored following these rules:

| Parameter name in API | Z80 Register |
| --------------------- | ------------ |
| u8 dev                | `H`          |
| u8 ndev               | `E`          |
| u8 flags              | `H`          |
| u8 cmd                | `C`          |
| u8 letter             | `D`          |
| u8 code               | `H`          |
| u8 fs                 | `E`          |
| u8 id                 | `H`          |
| u8 whence             | `A`          |
| u16 buf               | `DE`         |
| u16 size              | `BC`         |
| u16 name              | `BC`         |
| u16 dst               | `DE`         |
| u16 arg               | `DE`         |
| u16 path              | `DE`         |
| u16 argv              | `DE`         |
| u16 duration          | `DE`         |
| u16 time              | `DE`         |
| u16 date              | `DE`         |
| u24 src               | `HBC`        |
| u32 offset            | `BCDE`       |


And finally, the code must perform an `RST $08` instruction (please check [Reset vectors](#reset-vectors)).

The returned value is placed in A. The meaning of that value is specific to each call, please check the documentation of the concerned routines for more information.

### Syscall parameters constraints

To maximize user programs compatibility with Zeal 8-bit OS kernel, regardless of whether the kernel was compiled in MMU or no-MMU mode, the syscalls parameters constraints are the same:

<b>Any buffer passed to a syscall shall **not** cross a 16KB virtual pages</b>

In other words, if a buffer `buf` of size `n` is located in virtual page `i`, its last byte, pointed by `buf + n - 1`, must also be located on the exact same page `i`.

For example, if `read` syscall is called with:
* `DE = 0x4000` and `BC = 0x1000`, the parameters are **correct**, because the buffer pointed by `DE` fits into page 1 (from `0x4000` to `0x7FFF`)
* `DE = 0x4000` and `BC = 0x4000`, the parameters are **correct**, because the buffer pointed by `DE` fits into page 1 (from `0x4000` to `0x7FFF`)
* `DE = 0x7FFF` and `BC = 0x2`, the parameters are **incorrect**, because the buffer pointed by DE is in-between page 1 and page2.

### Syscall `exec`

Even though Zeal 8-bit OS is a mono-tasking operating system, it can execute and keep several programs in memory. When a program A executes a program B thanks to the `exec` syscall, it shall provide a `mode` parameter that can be either `EXEC_OVERRIDE_PROGRAM` or `EXEC_PRESERVE_PROGRAM`:
* `EXEC_OVERRIDE_PROGRAM`: this option tells the kernel that program A doesn't need to be executed anymore, so program B will be loaded in the same address space as program A. In other words, program B will be loaded inside the same RAM pages as program A, it will overwrite it.
* `EXEC_PRESERVE_PROGRAM`: this option tells the kernel that program A needs to be kept in RAM until program B finishes its execution and calls the `exit` syscall. To do so, the kernel will allocate 3 new memory pages (`16KB * 3 = 48KB`) in which it stores newly loaded program B. Once program B exits, the kernel frees the previously allocated pages for program B, remaps program A's memory pages, and gives back the hand to program A. If needed, A can retrieve B's exit value.

The depth of the execution tree is defined in the `menuconfig`, thanks to option `CONFIG_KERNEL_MAX_NESTED_PROGRAMS`. It represents the maximum number of programs that can be stored in RAM at one time. For example, if the depth is 3, program A can call program B, program B can call program C, but program C cannot call any other program.
However, if a program invokes `exec` with `EXEC_OVERRIDE_PROGRAM`, the depth is **not** incremented as the new program to load will override the current one.
As such, if we take back the previous example, program C can call a program if and only if it invokes the `exec` syscall in `EXEC_OVERRIDE_PROGRAM` mode.

Be careful, when executing a sub-program, the whole opened device table, (including files, directories, and drivers), the current directory, and CPU registers will be **shared**.

This means that if program A opens a file with descriptor 3, program B will inherit this index, and thus, also be able to read, write, or even close that descriptor. Reciprocally, if B opens a file, directory, or driver and exits **without** closing it, program A will also have access to it. As such, the general guideline to follow is that before exiting, a program must always close the descriptors it opened. The only moment the table of opened devices and current directory are reset is when the initial program (program A in the previous example) exits. In that case, the kernel will close all the descriptors in the opened devices table, reopen the standard input and output, and reload the initial program.

This also means that when invoking the `exec` syscall in an assembly program, on success, all registers, except HL, must be considered altered because they will be used by the subprogram. So, if you wish to preserve `AF`, `BC`, `DE`, `IX` or `IY`, they must be pushed on the stack before invoking `exec`.

### Syscall documentation

The syscalls are all documented in the header files provided for both assembly and C, you will find [assembly headers here](https://github.com/Zeal8bit/Zeal-8-bit-OS/tree/main/kernel_headers/z88dk-z80asm) and [C headers here](https://github.com/Zeal8bit/Zeal-8-bit-OS/tree/main/kernel_headers/sdcc/include) respectively.

## Drivers

A driver consists of a structure containing:

* Name of the driver, maximum 4 characters (filled with NULL char if shorter). For example, `SER0`, `SER1`, `I2C0`, etc. Non-ASCII characters are allowed but not advised.
* The address of an `init` routine, called when the kernel boots.
* The address of `read` routine, where parameters and return address are the same as in the syscall table.
* The address of `write` routine, same as above.
* The address of `open` routine, same as above.
* The address of `close` routine, same as above.
* The address of `seek` routine, same as above.
* The address of `ioctl` routine, same as above.
* The address of `deinit` routine, called when unloading the driver.

Here is the example of a simple driver registration:
```C
my_driver0_init:
        ; Register itself to the VFS
        ; Do something
        xor a ; Success
        ret
my_driver0_read:
        ; Do something
        ret
my_driver0_write:
        ; Do something
        ret
my_driver0_open:
        ; Do something
        ret
my_driver0_close:
        ; Do something
        ret
my_driver0_seek:
        ; Do something
        ret
my_driver0_ioctl:
        ; Do something
        ret
my_driver0_deinit:
        ; Do something
        ret

SECTION DRV_VECTORS
DEFB "DRV0"
DEFW my_driver0_init
DEFW my_driver0_read
DEFW my_driver0_write
DEFW my_driver0_open
DEFW my_driver0_close
DEFW my_driver0_seek
DEFW my_driver0_ioctl
DEFW my_driver0_deinit
```

Registering a driver consists in putting this information (structure) inside a section called `DRV_VECTORS`. The order is very important as any driver dependency shall be resolved at compile-time. For example, if driver `A` depends on driver `B`, then `B`'s structure must be put before `A` in the section `DRV_VECTORS`.

At boot, the `driver` component will browse the whole `DRV_VECTORS` section and initialize the drivers one by one by calling their `init` routine. If this routine returns `ERR_SUCCESS`, the driver will be registered and user programs can open it, read, write, ioctl, etc...

A driver can be hidden to the programs, this is handy for disk drivers that must only be accessed by the kernel's file system layer. To do so, the `init` routine should return `ERR_DRIVER_HIDDEN`.

## Virtual File System

As the communication between applications and hardware is all done through the syscalls described above, we need a layer between the user application and the kernel that will determine whether we need to call a driver or a file system. Before showing the hierarchy of such architecture, let's talk about disks and drivers.

### Architecture of the VFS

The different layers can be seen like this:

```mermaid
flowchart TD;
        app(User program)
        vfs(Virtual File System)
        dsk(Disk module)
        drv(Driver implementation: video, keyboard, serial, etc...)
        fs(File System)
        sysdis(Syscall dispatcher)
        hw(Hardware)
        time(Time & Date module)
        mem(Memory module)
        loader(Loader module)
        app -- syscall/rst 8 --> sysdis;
        sysdis --getdate/time--> time;
        sysdis --mount--> dsk;
        sysdis --> vfs;
        sysdis --map--> mem;
        sysdis -- exec/exit --> loader;
        vfs --> dsk & drv;
        dsk <--> fs;
        fs --> drv;
        drv --> hw;
```

## Disks

Zeal 8-bit OS supports up to 26 disks at once. The disks are denoted by a letter, from A to Z. It's the disk driver's responsibility to decide where to mount the disk in the system.

The first drive, `A`, is special as it is the one where the system will look for preferences or configurations.

In an application, a `path` may be:

* Relative to the current path, e.g. `my_dir2/file1.txt`
* Absolute, referring to the current disk, e.g. `/my_dir1/my_dir2/file1.txt`
* Absolute, referring to another disk, e.g. `B:/your_dir1/your_dir2/file2.txt`

## File systems

Even though the OS is completely ROM-able and doesn't need any file system or disk to boot, as soon as it will try to load the initial program, called `init.bin` by default, it will check for the default disk and request that file. Thus, even the most basic storage needs a file system, or something similar.

* The first "file system", which is already implemented, is called "rawtable". As its name states, it represents the succession of files, not directories, in a storage device, in no particular order. The file name size limit is the same as the kernel's: 16 characters, including the optional `.` and extension. If we want to compare it to C code, it would be an array of structures defining each file, followed by the file's content in the same order. A romdisk packer source code is available in the `packer/` at the root of this repo. Check [its README](packer/README.md) for more info about it.

* The second file system, which is also implemented, is named ZealFS. Its main purpose is to be embedded in very small storages, from 8KB up to 64KB. It is readable and writable, it supports files and directories. [More info about it in the dedicated repository](https://github.com/Zeal8bit/ZealFS).

* The third file system that would be nice to have on Zeal 8-bit OS is FAT16. Very famous, already supported by almost all desktop operating systems, usable on CompactFlash and even SD cards, this is almost a must-have. It has **not** been implemented yet, but it's planned. FAT16 is not perfect though as it is not adapted for small storage, this is why ZealFS is needed.

# Supported targets

## Relation with the kernel

The Zeal 8-bit OS is based on two main components: a kernel and a target code.
The kernel alone does nothing. The target needs to implement the drivers, some MMU macros used inside the kernel and a linker script. The linker script is fairly simple, it lists the sections in the order they must be linked in the final binary by `z80asm` assembler.

The kernel currently uses the following sections, which must be included in any linker script:
* `RST_VECTORS`: contains the reset vectors
* `SYSCALL_TABLE`: contains a table where syscall `i` routine address is stored at index `i`, must be aligned on 256
* `SYSCALL_ROUTINES`: contains the syscall dispatcher, called from a reset vector
* `KERNEL_TEXT`: contains the kernel code
* `KERNEL_STRLIB`: contains the string-related routines used in the kernel
* `KERNEL_DRV_VECTORS`: represents an array of drivers to initialize, check [Driver section](#drivers) for more details.
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
* Create an `mmu_h.asm` file which will be included by the kernel to configure and use the MMU. Check the file [`target/zeal8bit/include/mmu_h.asm`](target/zeal8bit/include/mmu_h.asm) to see how it should look like.
* Make sure to have at least one driver that mounts a disk, with the routine `zos_disks_mount`, containing an `init.bin` file, loaded and executed by the kernel on boot.
* Make sure to have at least one driver which registers itself as the standard out (stdout) with the routine `zos_vfs_set_stdout`.

# Version History

For the complete changelog, [please check the release page](https://github.com/Zeal8bit/Zeal-8-bit-OS/releases/).

# Contributing

Contributions are welcome! Feel free to fix any bug that you may see or encounter, or implement any feature that you find important.

To contribute:
  * Fork the Project
  * Create your feature Branch (*optional*)
  * Commit your changes. Please make a clear and concise commit message (*)
  * Push to the branch
  * Open a Pull Request


(*) A good commit message is as follows:
```
Module: add/fix/remove a from b

Explanation on what/how/why
```
For example:
```
Disks: implement a get_default_disk routine

It is now possible to retrieve the default disk of the system.
```

# License

Distributed under the Apache 2.0 License. See `LICENSE` file for more information.

You are free to use it for personal and commercial use, the boilerplate present in each file must not be removed.

# Contact

For any suggestion or request, you can contact me at contact [at] zeal8bit [dot] com

For feature requests, you can also open an issue or a pull request.
