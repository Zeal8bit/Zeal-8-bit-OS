#!/usr/bin/env python3

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

VERBOSE = False
DEBUG = False


def load_kconfig(config_path):
    """Parse a Kconfig .config file and return a dictionary of config values."""
    config = {}
    if not os.path.exists(config_path):
        print(f"{config_path} not found!")
        return config

    with open(config_path, "r") as f:
        for line in f:
            line = line.strip()
            # Skip comments and empty lines
            if not line or line.startswith("#"):
                continue
            # Parse CONFIG_KEY=value or CONFIG_KEY="value"
            if "=" in line:
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip()
                # Remove quotes from string values
                if value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]
                # Handle boolean values
                elif value == "y":
                    value = True
                elif value == "n":
                    value = False
                config[key] = value

    return config


def is_hidden_file(filepath):
    """Check if a file is hidden (cross-platform)."""
    basename = os.path.basename(filepath)

    # Unix/Linux/macOS: files starting with '.'
    if basename.startswith("."):
        return True

    # Windows: check hidden attribute
    if sys.platform == "win32":
        try:
            import ctypes

            attrs = ctypes.windll.kernel32.GetFileAttributesW(str(filepath))
            return attrs != -1 and bool(attrs & 2)
        except:
            return False

    return False


def get_files(command_line_paths):
    """Get all files from command line and config, expanding directories."""

    config_path = os.environ.get("KCONFIG_CONFIG", False)
    if config_path == False:
        zos_path = os.path.relpath(os.environ.get("ZOS_PATH", "."))
        config_path = os.path.join(zos_path, "os.conf")
    if VERBOSE: print("Config File: ", os.path.relpath(config_path))
    config = load_kconfig(config_path)
    config_files = []
    if "CONFIG_ROMDISK_EXTRA_FILES" in config and config["CONFIG_ROMDISK_EXTRA_FILES"]:
        config_files = [os.path.abspath(p) for p in config["CONFIG_ROMDISK_EXTRA_FILES"].split()]

    # Get files from environment variable
    env_files = []
    if "EXTRA_ROMDISK_FILES" in os.environ and os.environ["EXTRA_ROMDISK_FILES"]:
        env_files = [os.path.abspath(p) for p in os.environ["EXTRA_ROMDISK_FILES"].split()]

    # Check if we should ignore hidden files
    ignore_hidden = config.get("CONFIG_ROMDISK_IGNORE_HIDDEN", False)

    # Merge and deduplicate using set (all paths are now absolute)
    all_paths = list(set(command_line_paths + config_files + env_files))

    if DEBUG: print("Arg: ", [os.path.relpath(p) for p in command_line_paths])
    if DEBUG: print("Env: ", [os.path.relpath(p) for p in env_files])
    if DEBUG: print("Config: ", [os.path.relpath(p) for p in config_files])
    if VERBOSE: print("Paths: ", [os.path.relpath(p) for p in all_paths])

    # Expand directories to their files
    all_files = []
    for path in all_paths:
        if os.path.isdir(path):
            for entry in os.listdir(path):
                # Skip hidden and dot files if configured
                if ignore_hidden and is_hidden_file(entry):
                    print(f"Skipping hidden file: {entry}")
                    continue

                full_path = os.path.join(path, entry)
                if os.path.isfile(full_path):
                    all_files.append(full_path)
                else:
                    print(f"Skipping directory: {os.path.relpath(full_path)}")
        elif os.path.isfile(path):
            all_files.append(path)
        else:
            print(f"{sys.argv[0]}: Warning: '{os.path.relpath(path)}' is not a file or directory, skipping.")

    return all_files


def to_bcd(value):
    return ((value // 10) << 4) | (value % 10)


def build_entry_function(name, size, mtime):
    def build_entry(offset):
        t = time.localtime(mtime)
        year_hi = to_bcd(t.tm_year // 100)
        year_lo = to_bcd(t.tm_year % 100)

        print(f"\t{name:<16} {size:>5}B")

        entry = struct.pack(
            "<16sIIBBBBBBBB",
            name.encode("ascii").ljust(16, b"\0"),
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
        if os.path.isdir(path):  # should not reach this, but just in case
            print(f"Skipping directory '{os.path.relpath(path)}'")
            continue

        base = os.path.basename(path)
        base_ascii = base.encode("ascii", errors="ignore").decode("ascii")

        if len(base_ascii) > MAX_NAME_LENGTH:
            print(
                f"{sys.argv[0]}: Filename '{base_ascii}' too long, truncating to 16 characters."
            )
            base_ascii = base_ascii[:MAX_NAME_LENGTH]

        if base_ascii in seen_names:
            print(
                f"{sys.argv[0]}: Duplicate filename '{base_ascii}' (after truncation). Skipping."
            )
            continue
        seen_names.add(base_ascii)

        size = os.path.getsize(path)
        mtime = os.path.getmtime(path)

        # Read the file content and generate the entry builder function
        with open(path, "rb") as f:
            content = f.read()
            # Put a pair (function, content) in the entries list
            entries.append((build_entry_function(base_ascii, size, mtime), content))

    print("Packed: ")
    # Now that we have all the files content and the offset functions, we can generates the actual offsets and entries
    # Offset starts at the end of the header, which we can now determine
    offset = 2 + ENTRY_SIZE * len(entries)
    total_size = 0
    with open(output_file, "wb") as out:
        # Write the number of entries in the file
        out.write(struct.pack("<H", len(entries)))
        # Write all the entries
        for entry_fn, content in entries:
            out.write(entry_fn(offset))
            offset += len(content)
            total_size += len(content)
        # Write all the content
        for _, content in entries:
            out.write(content)

    print(f"Packed {len(entries)} files ({total_size}B) into '{output_file}'.")


if __name__ == "__main__":
    print("Preparing romdisk")

    args = sys.argv[1:]
    if "-v" in args or "--verbose" in args:
        VERBOSE = True
        args = [arg for arg in args if arg not in ["-v", "--verbose"]]

    if "-d" in args or "--debug" in args:
        DEBUG = True
        VERBOSE = True
        args = [arg for arg in args if arg not in ["-d", "--debug"]]

    if len(args) < 1:
        print(f"Usage: {sys.argv[0]} [-v] [-d] output.rom [input1 input2 ...]")
        sys.exit(1)

    all_files = get_files(args[1:])

    if len(all_files) < 1:
        print(f"{sys.argv[0]}: Error: No input files specified (via command line or CONFIG_ROMDISK_EXTRA_FILES).")
        sys.exit(1)

    pack_rom(args[0], all_files)
