# SDCC example for Zeal 8-bit OS

This directory contains an example of how to use and compile the Zeal 8-bit OS kernel C header files provided in `kernel_headers/sdcc`.

## How to compile

In order to compile the example, you will need SDCC v4.2.0 or above. Indeed, the kernel header implementation uses `__sdcccall(1)` calling convention, which is not supported in earlier SDCC versions.
Thus, make sure SDCC is properly installed and up to date in the system.

Then, to compile this example, you will only need the following command:
```
make
```

The output should look like this:
```
mkdir -p bin
sdcc -mz80 -c --codeseg TEXT -I../../sdcc/include/ -o bin/./ src/main.c
sdcc -mz80 -c --codeseg TEXT -I../../sdcc/include/ -o bin/./ src/str.c
sdldz80 -n -mjwx -i -b _HEADER=0x4000 -k /usr/local/share/sdcc/lib/z80 -l z80 bin/example.ihx ../../sdcc/bin/zos_crt0.rel bin/main.rel bin/str.rel
objcopy --input-target=ihex --output-target=binary bin/example.ihx bin/example.bin
Success, binary generated: bin/example.bin
```

As stated on the final line, the binary that can be transferred and executed by Zeal 8-bit OS is `bin/example.bin`.

## How to use

Once loaded in Zeal 8-bit OS, the program will print all the files and directories located in the system current working directory.

If you are familiar with the terminal, this is a cheap equivalent of `ls` command.

## Modifying this example

In order to extend this example, you will need to open and modify the `Makefile`. At first glance, this `Makefile` may seem intimidating but don't panic, its purpose is to be used as a template. In fact, this whole example is meant to be used as a template for you project or program.

In the `Makefile`, modify `SRCS` variable to list all the C files from `src/` folder to be compiled. Because of the way the `Makefile` is done and the limitation of SDCC, only C files can be provided in this variable.

## More details about what Makefile does underneath

To go into more details, there are several limitations in SDCC that make this `Makefile` a bit complex. For example, SDCC doesn't support compiling multiple files at once, in a single command line. Thus, we need to compile each of our files into `rel` (object files) independently and then link them all together.

This is why this example has two files, `main.c` and `str.c`.

Moreover, Zeal 8-bit OS expects all the user programs to start at `0x4000`, so the `crt0`, which is responsible for initializing the global and static variables as well as exiting once `main` returns, must start at `0x4000`. This is not possible without customizing the linker phase. At link time, it is necessary to relocated the `_HEADER` section, which is where the `crt0` is located, and place all the other sections after it.

## "Couldn't find library 'z80'"

If you haven't installed SDCC at the default location, you will need to specify the place where the linker can find the `z80` library provided by SDCC.

To do so, before executing `make`, add the following environment variable:
```
export SDLD_FLAGS="-k <path_to_sdcc_install>/lib/z80"
```

## Cleaning the binaries

Two possibilities to clean the resulted binaries:
* Delete the binary folder:
    ```
    rm -r bin
    ```
* Use make:
    ```
    make clean
    ```
