# Makefile build example (z88dk-z80asm)

This example showcases the **Makefile** build system for the z88dk-z80asm
toolchain. It does not have its own source code: it reuses the `hello_world`
example source via the relative path `../hello_world/src`.

Building it is equivalent to building `hello_world`:

```bash
export ZOS_PATH=/path/to/Zeal-8-bit-OS
cd examples/z88dk-z80asm/makefile
make
```

The resulting binary is `main.bin` (in the current directory).

This proves that the same sources can be built with either CMake (see the other
examples) or plain `make` (this one).
