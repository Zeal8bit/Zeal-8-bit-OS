# SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
#
# SPDX-License-Identifier: Apache-2.0


# In our examples and libraries, we want the code to be put in area/section _TEXT
# and not _CODE section. Indeed, SDAS assembler always puts _CODE section first,
# which prevents us from having any section preceding it, including _HEADER one.
# Let's patch SDCC z80.lib library to use _TEXT instead of _CODE

import sys
import re

if len(sys.argv) != 3:
    print("usage: %s input_z80.lib output_z80.lib" % sys.argv[0])
    exit(1)

in_lib = sys.argv[1]
out_lib = sys.argv[2]

# Open and read input library as a binary file
f = open(in_lib, "rb")
data = f.read()
f.close()

# Use regex to find and replace the string
new_data = re.sub(b"_CODE", b"_TEXT", data)

# Write the new library data to the output file
f = open(out_lib, "wb")
f.write(new_data)
