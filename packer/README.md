# Simple ROM packer

This program is used to create an image file which can be flashed to an EEPROM/ROM/FLASH. It represents a rawtable
of files that can be used with Zeal 8-bit OS's rawtable filesystem.

## Compiling

```
make
```

## Usage

```
./pack output_image_file input_file1 input_file2 ... input_fileN
```

The resulted image has the format described in Zeal 8-bit OS's `rawtable.asm` file.
