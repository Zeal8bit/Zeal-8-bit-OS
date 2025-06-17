# Assembly example for Zeal 8-bit OS

This directory contains a simple example of how to use and assemble the Zeal 8-bit OS kernel header file provided in `kernel_headers/z88dk-z80asm`.

## How to assemble

To assemble the example, you will need the `z80asm` binary from `z88dk`. Make sure that `z88dk` is properly installed and that the `ZOS_PATH` environment variable is set to the root of the Zeal 8-bit OS source.

### Using CMake

Setup the project using:
```
cmake --toolchain $ZOS_PATH/cmake/z88dk_toolchain.cmake -B bin
```

Then compile with:
```
cmake --build bin
```

The output binary will be placed in the `bin/` folder. By default, its name is `main.bin`.

You can change `bin` in the commands above to specify a different output directory.

### Using `make` (deprecated)

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
