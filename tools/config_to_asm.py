#!/usr/bin/python3

import sys

def convert_config_asm(input_path, output_path):
    with open(input_path, 'r') as infile, open(output_path, 'w') as outfile:
        outfile.write("IFNDEF OSCONFIG_H\nDEFINE OSCONFIG_H\n\n")

        for line in infile:
            line = line.strip()
            if not line.startswith("CONFIG_") or "=" not in line:
                continue

            key, value = line.split("=", 1)

            # Convert =y to =1, =n to =0
            if value == "y":
                value = "1"
            elif value == "n":
                value = "0"

            # Quoted value becomes MACRO
            if value.startswith('"') and value.endswith('"'):
                outfile.write(f"    MACRO {key}\n        DEFM {value}\n    ENDM\n")
            else:
                # Unquoted: numeric or boolean
                outfile.write(f"    DEFC {key} = {value}\n")

        outfile.write("\nENDIF\n")


if __name__ == "__main__":
    convert_config_asm(sys.argv[1], sys.argv[2])
