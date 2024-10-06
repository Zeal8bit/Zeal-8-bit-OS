The system relies on syscalls to perform requests between the user program and the kernel. Thus, this shall be the way to perform operations on the hardware. The possible operations are listed in the table below.

## Syscall table

| Num | Name    | Param. 1     | Param. 2   | Param. 3  |
| --- | ------- | ------------ | ---------- | --------- |
| 0   | read    | u8 dev       | u16 buf    | u16 size  |
| 1   | write   | u8 dev       | u16 buf    | u16 size  |
| 2   | open    | u16 name     | u8 flags   |           |
| 3   | close   | u8 dev       |            |           |
| 4   | dstat   | u8 dev       | u16 dst    |           |
| 5   | stat    | u16 name     | u16 dst    |           |
| 6   | seek    | u8 dev       | u32 offset | u8 whence |
| 7   | ioctl   | u8 dev       | u8 cmd     | u16 arg   |
| 8   | mkdir   | u16 path     |            |           |
| 9   | chdir   | u16 path     |            |           |
| 10  | curdir  | u16 path     |            |           |
| 11  | opendir | u16 path     |            |           |
| 12  | readdir | u8 dev       | u16 dst    |           |
| 13  | rm      | u16 path     |            |           |
| 14  | mount   | u8 dev       | u8 letter  | u8 fs     |
| 15  | exit    | u8 code      |            |           |
| 16  | exec    | u16 name     | u16 argv   |           |
| 17  | dup     | u8 dev       | u8 ndev    |           |
| 18  | msleep  | u16 duration |            |           |
| 19  | settime | u8 id        | u16 time   |           |
| 20  | gettime | u8 id        | u16 time   |           |
| 21  | setdate | u16 date     |            |
| 22  | getdate | u16 date     |            |
| 23  | map     | u16 dst      | u24 src    |           |
| 24  | swap    | u8 dev       | u8 ndev    |           |

Please check the [section below](#syscall-parameters) for more information about each of these call and their parameters.

!!! note
    Some syscalls may be unimplemented. For example, on computers where directories are not supported,directories-related syscalls may be omitted.

## Syscall parameters

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


And finally, the code must perform an `RST $08` instruction (please check [Reset vectors](kernel.md#reset-vectors)).

The returned value is placed in A. The meaning of that value is specific to each call, please check the documentation of the concerned routines for more information.

## Syscall parameters constraints

To maximize user programs compatibility with Zeal 8-bit OS kernel, regardless of whether the kernel was compiled in MMU or no-MMU mode, the syscalls parameters constraints are the same:

<b>Any buffer passed to a syscall shall **not** cross a 16KB virtual pages</b>

In other words, if a buffer `buf` of size `n` is located in virtual page `i`, its last byte, pointed by `buf + n - 1`, must also be located on the exact same page `i`.

For example, if `read` syscall is called with:
* `DE = 0x4000` and `BC = 0x1000`, the parameters are **correct**, because the buffer pointed by `DE` fits into page 1 (from `0x4000` to `0x7FFF`)
* `DE = 0x4000` and `BC = 0x4000`, the parameters are **correct**, because the buffer pointed by `DE` fits into page 1 (from `0x4000` to `0x7FFF`)
* `DE = 0x7FFF` and `BC = 0x2`, the parameters are **incorrect**, because the buffer pointed by DE is in-between page 1 and page2.

## Syscall `exec`

Even though Zeal 8-bit OS is a mono-tasking operating system, it can execute and keep several programs in memory. When a program A executes a program B thanks to the `exec` syscall, it shall provide a `mode` parameter that can be either `EXEC_OVERRIDE_PROGRAM` or `EXEC_PRESERVE_PROGRAM`:

* `EXEC_OVERRIDE_PROGRAM`: this option tells the kernel that program A doesn't need to be executed anymore, so program B will be loaded in the same address space as program A. In other words, program B will be loaded inside the same RAM pages as program A, it will overwrite it.
* `EXEC_PRESERVE_PROGRAM`: this option tells the kernel that program A needs to be kept in RAM until program B finishes its execution and calls the `exit` syscall. To do so, the kernel will allocate 3 new memory pages (`16KB * 3 = 48KB`) in which it stores newly loaded program B. Once program B exits, the kernel frees the previously allocated pages for program B, remaps program A's memory pages, and gives back the hand to program A. If needed, A can retrieve B's exit value.

The depth of the execution tree is defined in the `menuconfig`, thanks to option `CONFIG_KERNEL_MAX_NESTED_PROGRAMS`. It represents the maximum number of programs that can be stored in RAM at one time. For example, if the depth is 3, program A can call program B, program B can call program C, but program C cannot call any other program.
However, if a program invokes `exec` with `EXEC_OVERRIDE_PROGRAM`, the depth is **not** incremented as the new program to load will override the current one.
As such, if we take back the previous example, program C can call a program if and only if it invokes the `exec` syscall in `EXEC_OVERRIDE_PROGRAM` mode.

Be careful, when executing a sub-program, the whole opened device table, (including files, directories, and drivers), the current directory, and CPU registers will be **shared**.

This means that if program A opens a file with descriptor 3, program B will inherit this index, and thus, also be able to read, write, or even close that descriptor. Reciprocally, if B opens a file, directory, or driver and exits **without** closing it, program A will also have access to it. As such, the general guideline to follow is that before exiting, a program must always close the descriptors it opened. The only moment the table of opened devices and current directory are reset is when the initial program (program A in the previous example) exits. In that case, the kernel will close all the descriptors in the opened devices table, reopen the standard input and output, and reload the initial program.

This also means that when invoking the `exec` syscall in an assembly program, on success, all registers, except HL, must be considered altered because they will be used by the subprogram. So, if you wish to preserve `AF`, `BC`, `DE`, `IX` or `IY`, they must be pushed on the stack before invoking `exec`.

## Syscall documentation

The syscalls are all documented in the header files provided for both assembly and C, you will find [assembly headers here](https://github.com/Zeal8bit/Zeal-8-bit-OS/tree/main/kernel_headers/z88dk-z80asm) and [C headers here](https://github.com/Zeal8bit/Zeal-8-bit-OS/tree/main/kernel_headers/sdcc/include) respectively.
