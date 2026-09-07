# Assembly header file for z88dk's z80asm assembler

In this directory, you will find an assembly file, `zos_sys.asm`, that acts as an header file. Indeed, it shall be included by any assembly project targeting Zeal 8-bit OS.

This file is fairly simple, it contains macros for all the syscalls available in Zeal 8-bit OS kernel. For more info about each of them, check the header file directly.

## Usage

The following line needs be added at the top of the assembly file using Zeal 8-bit OS syscalls:
```
    INCLUDE "zos_sys.asm"
```

When assembling, either copy this file in the project's directory, either provide the following option to `z80asm`:
```
z88dk-z80asm -I<path_to_directory_containing_zos_sys.asm>
```

## Building Libraries

To build a library, such as `strutils`, the library must have its own directory under `src`. Inside this directory, there must be a file named `files.txt` that lists all the files included in the library.

Each function in the library should be placed in its own file. This approach allows unused functions to be excluded from the final program, optimizing the size of the resulting binary.

For example, the `files.txt` for `strutils` might look like this:
```
strcat.asm
strlen.asm
strcpy.asm
```

When assembling a program that uses this library, only the required functions will be included saving space.