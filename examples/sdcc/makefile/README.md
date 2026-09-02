# Makefile build example (sdcc)

This example shows how to build a program with a plain `Makefile`, using the SDCC toolchain. It has no source code of its own: it reuses the `hello_world` example source through the relative path `../hello_world/src`, thanks to the shared `base_sdcc.mk`.

Building it is equivalent to building `hello_world`:

```bash
export ZOS_PATH=/path/to/Zeal-8-bit-OS
cd examples/sdcc/makefile
make
```

The resulting binary is `bin/makefile.bin`.
