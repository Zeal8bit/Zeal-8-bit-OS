#!/usr/bin/python3

import sys
import os

def usage():
    print(f"Usage: {sys.argv[0]} output_file address_1 file_1 ... address_n file_n", file=sys.stderr)

def main():
    # We must have an even number of arguments (and more than 4)
    args_count = len(sys.argv)
    if args_count < 4 or (args_count & 1) != 0:
        usage()
        return 1

    # Create the output file (truncate if it exists)
    output_file = sys.argv[1]
    with open(output_file, 'wb+') as out_file:
        # Process the address and file pairs
        for i in range(2, args_count, 2):
            addr = int(sys.argv[i], 0)
            file = sys.argv[i + 1]

            # Make sure the file exists
            if not os.path.isfile(file):
                print(f"Error: File {file} not found", file=sys.stderr)
                return 2

            print(f"0x{addr:04x} - {file}")

            # Read the input file and write it to the output file at the specified address
            with open(file, 'rb') as in_file:
                data = in_file.read()
                out_file.seek(addr)
                out_file.write(data)
    return 0

if __name__ == "__main__":
    sys.exit(main())
