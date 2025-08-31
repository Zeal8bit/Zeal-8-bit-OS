# GNU Assembler example for Zeal 8-bit OS

This directory contains a simple example of how to write and assemble a user program for Zeal 8-bit OS using GNU's assembler. The kernel header files provided in `kernel_headers/gnu-as` will be used here.

## How it works

### Generating the binary

GNU's assembler, `z80-elf-as`, generates a binary file for each assembly source file. Then, the linker `z80-elf-ld` will gather all these binary files and make an ELF file out of them.

Of course, ELF format being very complex and heavy for an 8-bit computer, it is not loaded by Zeal 8-bit OS. The build system will use `z80-elf-objcopy` to extract the sections containing code and data, and make a raw binary out of them. This binary can them be loaded by Zeal 8-bit OS.

## How to assemble

To assemble this example, you will need binutils compiled for `z80-elf` target. Make sure you have at least `z08-elf-as`, `z08-elf-ld` and ``z08-elf-objcopy` installed in your system. Also, make sure that the `ZOS_PATH` environment variable is set to the root of the Zeal 8-bit OS source.

### Using CMake (Recommended)

Setup the project using:

```
mkdir build
cd build
cmake ..
```

Then compile with:

```
make
```

The output binary will be placed in the `bin/` folder. By default, its name is `main.bin`.

You can change `bin` in the commands above to specify a different output directory.

### Using `make`

To compile this example, you will only need the following command:
```
make
```

The output binary should be present in the `bin/` folder. By default, its name is `main.bin`.

## How to use

Once loaded in Zeal 8-bit OS, the program will show a message on screen:
```
Type your name:
```
The user is invited to type his name, then after enter is pressed, the program terminates with the message:
```
Hello <name typed>
```
