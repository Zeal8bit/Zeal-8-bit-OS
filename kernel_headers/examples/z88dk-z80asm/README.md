# Assembly example for Zeal 8-bit OS

This directory contains a simple example of how to use and assemble the Zeal 8-bit OS kernel header file provided in `kernel_headers/z88dk-z80asm`.

## How to assemble

In order to assemble the example, you will need `z88dk`'s `z80asm` binary. Make sure `z88dk` is properly installed in the system.

Then, to compile this example, you will only need the following command:
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

## Modifying this example

In order to modify this example to add more files to the assembly process, open the `Makefile` and modify accordingly the following variable:
```
SRCS = main.asm
```