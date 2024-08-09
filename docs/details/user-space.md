## Entry point

When a user program is executed, the kernel allocates 3 pages of RAM (48KB), reads the binary file to execute and loads it starting at virtual address `0x4000` by default. This entry point virtual address is configurable through the `menuconfig` with option `KERNEL_INIT_EXECUTABLE_ADDR`, but keep in mind that existing programs won't work anymore without being recompiled because they are not relocatable at runtime.

## Program parameters

As described below, the `exec` syscall takes two parameters: a binary file name to execute and a parameter.

This parameter must be a NULL-terminated string that will be copied and transmitted to the binary to execute through registers `DE` and `BC`:

* `DE` contains the address of the string. This string will be copied to the new program's memory space, usually on top of the stack.
* `BC` contains the length of that string (so, excluding the NULL-byte). If `BC` is 0, `DE` **must** be discarded by the user program.
