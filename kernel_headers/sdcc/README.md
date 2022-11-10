# C header files for SDCC

## Syscall Interface

In the `include` directory, you will find C header files that give the interface for each of Zeal 8-bit OS kernel syscall to any C source file.

These files also act as the official documentation as all the functions are properly documented.

Currently, only **SDCC v4.2.0** supports the `__sdcccall(1)` convention, used in the interface implementation, thus, earlier version are not supported yet.

## Interface implementation

The directory `src` contains both the implementation of these C functions, which acts as a glue between C runtime and kernel's assembly syscalls, and the `crt0` module. The `crt0` module is a small portion of code that is executed right before the `main` function. Its goal is to initialize the global and static variables. Moreover, it will also `exit` properly the program once `main` exits.

## Building from source

**Note: In the `bin` folder, a `rel` binary is already provided, there is no need to recompile the source if they have not been modified.**

Before compiling, make sure you have `sdasz80` binary installed. If that's not the case, install SDCC 4.2.0.

Once it is installed, to compile the sources, simply type:
```
make
```

The output should be as followed:
```
Assembling Zeal 8-bit OS library and crt0 files...
sdasz80 -f -o bin/zos_crt0.rel src/zos_crt0.asm src/zeal8bitos.asm
```

The interface implementation results in a `zos_crt0.rel` binary (SDCC `Relocatable` binaries) located in the `bin` folder. This binary contains **both** the `crt0` **and** the syscall interface implementation.

## Usage

In order to generate a proper binary that will be run on Zeal 8-bit OS, several things needs to be done:

* Place all the code in the `_TEXT` area. Indeed, the default `_CODE` area used by SDCC cannot be easily placed among other sections. To do so, use the following option when compiling:
    ```
    --codeseg TEXT
    ```
* When linking, relocate the `_HEADER` area to `0x4000`. Programs on Zeal 8-bit OS must start at `0x4000` virtual address. Thus, when compiling a C program, you need to tell SDCC to relocate the first area, `_HEADER` (containing the `crt0`) at `0x4000`. To do so, use the following option:
    ```
    -b _HEADER=0x4000
    ```
* Finally, you **must** link the `zos_crt0.rel` file **before** the other C files to compile.
    ```
    sdldz80 [..] -b _HEADER=0x4000 -l z80 -i <output_file> <path_to_zos_crt0/>zos_crt0.rel source1.rel source2.rel
    ```

## Usage example

Let's say we have two C files, `file1.c` and `file2.c`, that we want to compile, the steps are:
* Compile each C file into a `rel` file. Indeed, SDCC doesn't support compiling several C file at the same time. We must provide `-c` to say we want to compile but not link:
    ```
    sdcc -mz80 -c --codeseg TEXT -I<path_to_zos_headers> file1.c
    sdcc -mz80 -c --codeseg TEXT -I<path_to_zos_headers> file2.c
    ```
* Link the resulted binary with Zeal rel file:
    ```
    sdldz80 -n -x -i -b _HEADER=0x4000 -k /usr/local/share/sdcc/lib/z80 -l z80 output.ihx <path_to_zos_crt0.rel> file1.rel file2.rel
    ```
    Note: replace `/usr/local/share/sdcc/lib/z80` if that's not the path of your SDCC installation.
* Finally, convert the resulted Intel Hex binary to a real binary file:
    ```
    objcopy --input-target=ihex --output-target=binary output.ihx output.bin
    ```

For more info about a practical usage, check the example located in `kernel_headers/examples/sdcc`.

## Cleaning the binary

Two possibilities to clean the compiled binary:
* Delete the binary folder:
    ```
    rm -r bin
    ```
* Use make:
    ```
    make clean
    ```
