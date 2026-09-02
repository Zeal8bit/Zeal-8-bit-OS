# Examples

This directory contains example user programs for Zeal 8-bit OS, one folder per
toolchain, with each example being self-contained (own `src/` and
`CMakeLists.txt`). All examples are built with **CMake**, except the `makefile`
example per toolchain, which showcases a plain `make` build reusing the
`hello_world` sources.

- [`gnu-as/`](gnu-as/) — assembly, assembled with `z80-elf-as`
- [`sdcc/`](sdcc/) — C, compiled with SDCC 4.2.0+
- [`z88dk-z80asm/`](z88dk-z80asm/) — assembly, assembled with `z88dk-z80asm`

The public kernel headers and libraries used by these examples are in the
[`sdk/`](../sdk/) directory.

## Build

Every example is built with CMake, except the `makefile` example which shows
how to build with plain `make`. Set the `ZOS_PATH` environment variable to the
root of this repository first. Check the README in each toolchain directory for
details.

## Test

Following the ESP-IDF convention, each example has its own test file,
`pytest_<example>.py`, located directly inside its directory. The shared
build/run logic lives in `tests/helpers.py`. See
[`tests/README.md`](tests/README.md) for details.
