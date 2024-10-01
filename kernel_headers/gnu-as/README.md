# Assembly header file for GNU's assembler (z80-elf)

In this directory, you will find several assembly files that act as headers file. They can be included in any assembly file meant to be assembly with GNU's assembler `z80-elf-as`. Of course, the project should be targetting Zeal 8-bit OS.

These files contain macros for all the syscalls available in Zeal 8-bit OS kernel. For more info about each of them, check the header file directly.

## Usage

To include one of the files, use the `.include` directive, for example:
```
    .include "zos_sys.asm"
```

When assembling your porject, make sure to add this directory as an include directory. You can use the following command option:
```
-I$ZOS_PATH/kernel_headers/gnu-as/
```

Where `ZOS_PATH` is the environment variable that points to the root directory of Zeal 8-bit OS.