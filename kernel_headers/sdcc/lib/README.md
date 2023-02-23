# Z80 Library

This library, `z80.lib`, is a patched version of the one provided by SDCC. The patch consist in replacing all the occurrences of `_CODE` by `_TEXT`. As such, all the code that is part of the library will be put in the `_CODE` section.

For more information about why we need to use `_TEXT` instead of `_CODE`, please check the `README.md` in the upper directory.

## Generating the patch library

In order to generate the patched library from SDCC's `z80.lib` file, use the following command:
```
python3 patch_lib_code.py <path/to/sdcc/z80.lib> <output_file_z80.lib>
```

## License

The patched Z80 library retains its original license (if it has one). As you can see in the python script, the lib is patched from the binary file, and not from source code.