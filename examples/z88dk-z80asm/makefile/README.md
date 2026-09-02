# Makefile build example (z88dk-z80asm)

This example shows how to build a program with a plain `Makefile`, using the z88dk-z80asm toolchain. It has no source code of its own: it reuses the `hello_world` example source through the relative path `../hello_world/src`.

Building it is equivalent to building `hello_world`:

```bash
export ZOS_PATH=/path/to/Zeal-8-bit-OS
cd examples/z88dk-z80asm/makefile
make
```

The resulting binary is `main.bin` (in the current directory).
