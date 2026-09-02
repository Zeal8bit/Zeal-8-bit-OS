# z88dk-z80asm examples

This directory contains examples of user programs for Zeal 8-bit OS written in
assembly and assembled with `z88dk-z80asm`. They all use the kernel headers
provided in the `sdk/z88dk-z80asm/` directory.

Each example is self-contained: it has its own `src/` directory and a
`CMakeLists.txt`. The `makefile` example shows the alternative `make` build.

| Example | Description |
|---------|-------------|
| `hello_world` | Minimal program: prints "Hello World!" on the standard output. |
| `echo` | Prints a prompt, reads a line from the standard input and greets you. |
| `raw_keyboard` | Puts the keyboard in raw mode and echoes every pressed key until Enter. |
| `makefile` | Shows how to build with plain `make`, reuses the `hello_world` source. |

## Build an example

All examples are built with **CMake** (the recommended way), except `makefile`
which showcases a plain `make` build. Set the `ZOS_PATH` variable to the root of
this repository first.

Using CMake:

```bash
export ZOS_PATH=/path/to/Zeal-8-bit-OS
cd examples/z88dk-z80asm/hello_world
mkdir build && cd build
cmake ..
make
```

The resulting raw binary is `build/main.bin`.

Using `make` (see the `makefile` example):

```bash
export ZOS_PATH=/path/to/Zeal-8-bit-OS
cd examples/z88dk-z80asm/makefile
make
```

The resulting raw binary is `main.bin` (in the current directory).

## Requirements

You need `z88dk-z80asm` from [z88dk](https://github.com/z88dk/z88dk) available
in your `PATH`.
