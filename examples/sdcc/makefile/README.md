# Makefile build example (sdcc)

This example showcases the **Makefile** build system for the SDCC toolchain.
It does not have its own source code: it reuses the `hello_world` example
source via the relative path `../hello_world/src`, through the shared
`base_sdcc.mk`.

Building it is equivalent to building `hello_world`:

```bash
export ZOS_PATH=/path/to/Zeal-8-bit-OS
cd examples/sdcc/makefile
make
```

The resulting binary is `bin/makefile.bin`.

This proves that the same sources can be built with either CMake (see the other
examples) or plain `make` (this one).
