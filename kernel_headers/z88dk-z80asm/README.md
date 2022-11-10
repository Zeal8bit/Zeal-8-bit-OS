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
