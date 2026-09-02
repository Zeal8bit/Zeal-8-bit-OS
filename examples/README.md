# Examples

This directory contains example user programs for Zeal 8-bit OS. There is one folder per toolchain and each example is standalone: it has its own `src/` directory and `CMakeLists.txt`. All examples are built with CMake, except the `makefile` example of each toolchain, which shows how to build the `hello_world` sources with a plain `make`.

- [`gnu-as/`](gnu-as/): assembly, assembled with `z80-elf-as`
- [`sdcc/`](sdcc/): C, compiled with SDCC 4.2.0+
- [`z88dk-z80asm/`](z88dk-z80asm/): assembly, assembled with `z88dk-z80asm`

The public kernel headers and libraries used by these examples are in the [`sdk/`](../sdk/) directory.

## Build

Set the `ZOS_PATH` environment variable to the root of this repository, then build the example with CMake, or with `make` for the `makefile` example. Check the README in each toolchain directory for more details.

## Test

Each example has its own test file, `pytest_<example>.py`, located directly inside its directory. The shared build and run logic lives in `tests/helpers.py`, see [`tests/README.md`](../tests/README.md) for more details.
