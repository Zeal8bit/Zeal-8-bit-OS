import os
import sys
import struct
import time

# In C, the equivalent entry structure would be:
#   typedef struct {
#       char name[MAX_NAME_LENGTH];
#       uint32_t size;
#       uint32_t offset;
#       uint8_t  year[2];
#       uint8_t  month;
#       uint8_t  day;
#       uint8_t  date;
#       uint8_t  hours;
#       uint8_t  minutes;
#       uint8_t  seconds;
#   } __attribute__((packed)) entry_t;
ENTRY_SIZE = 32
MAX_NAME_LENGTH = 16

def to_bcd(value):
    return ((value // 10) << 4) | (value % 10)

def build_entry_function(name, size, mtime):
    def build_entry(offset):
        t = time.localtime(mtime)
        year_hi = to_bcd(t.tm_year // 100)
        year_lo = to_bcd(t.tm_year % 100)

        entry = struct.pack(
            "<16sIIBBBBBBBB",
            name.encode("ascii").ljust(16, b'\0'),
            size,
            offset,
            year_hi,
            year_lo,
            to_bcd(t.tm_mon),
            to_bcd(t.tm_mday),
            to_bcd(t.tm_wday + 1),
            to_bcd(t.tm_hour),
            to_bcd(t.tm_min),
            to_bcd(t.tm_sec),
        )
        return entry
    return build_entry

def pack_rom(output_file, input_files):
    entries = []
    seen_names = set()

    # Start by creating reading all the files and ignore the duplicates
    # For each file we will get a function that will return the entry (binary) once we provide the offset
    for path in input_files:
        base = os.path.basename(path)
        base_ascii = base.encode("ascii", errors="ignore").decode("ascii")

        if len(base_ascii) > MAX_NAME_LENGTH:
            print(f"{sys.argv[0]}: Filename '{base_ascii}' too long, truncating to 16 characters.")
            base_ascii = base_ascii[:MAX_NAME_LENGTH]

        if base_ascii in seen_names:
            print(f"{sys.argv[0]}: Duplicate filename '{base_ascii}' (after truncation). Skipping.")
            continue
        seen_names.add(base_ascii)

        size = os.path.getsize(path)
        mtime = os.path.getmtime(path)

        # Read the file content and generate the entry builder function
        with open(path, "rb") as f:
            content = f.read()
            # Put a pair (function, content) in the entries list
            entries.append((build_entry_function(base_ascii, size, mtime), content))

    # Now that we have all the files content and the offset functions, we can generates the actual offsets and entries
    # Offset starts at the end of the header, which we can now determine
    offset = 2 + ENTRY_SIZE * len(entries)
    with open(output_file, "wb") as out:
        # Write the number of entries in the file
        out.write(struct.pack("<H", len(entries)))
        # Write all the entries
        for (entry_fn, content) in entries:
            out.write(entry_fn(offset))
            offset += len(content)
        # Write all the content
        for (_, content) in entries:
            out.write(content)

    print(f"{sys.argv[0]}: Packed {len(entries)} files into '{output_file}'.")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} output.rom input1 input2 ...")
        sys.exit(1)
    pack_rom(sys.argv[1], sys.argv[2:])
