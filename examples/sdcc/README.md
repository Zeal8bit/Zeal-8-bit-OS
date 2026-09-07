# SDCC examples

This directory contains examples of user programs for Zeal 8-bit OS written in
C and compiled with SDCC. They all use the kernel headers provided in the
`sdk/sdcc/` directory.

Each example is self-contained: it has its own `src/` directory and a
`CMakeLists.txt`. The `makefile` example shows the alternative `make` build.

| Example | Description |
|---------|-------------|
| `hello_world` | Minimal program printing a message with `printf`. |
| `raw_keyboard` | Puts the keyboard in raw mode and echoes every pressed key until Enter. |
| `mouse` | Opens the `#MOUS` driver and prints the accumulated mouse movement and buttons. |
| `dir_listing` | Opens the current directory and lists every entry, mixes `printf` and custom C code. |
| `makefile` | Shows how to build with plain `make`, reuses the `hello_world` source. |

## Build an example

All examples are built with **CMake** (the recommended way), except `makefile`
which showcases a plain `make` build. Set the `ZOS_PATH` variable to the root of
this repository first.

Using CMake:

```bash
export ZOS_PATH=/path/to/Zeal-8-bit-OS
cd examples/sdcc/hello_world
mkdir build && cd build
cmake ..
make
```

The resulting raw binary is `build/hello_world.bin`.

Using `make` (see the `makefile` example):

```bash
export ZOS_PATH=/path/to/Zeal-8-bit-OS
cd examples/sdcc/makefile
make
```

The resulting raw binary is `bin/makefile.bin`.

## Requirements

You need SDCC v4.2.0 or above. Indeed, the kernel header implementation uses
`__sdcccall(1)` calling convention, which is not supported in earlier SDCC
versions.
