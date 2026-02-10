#!/usr/bin/env python3
import sys
from pathlib import Path
import yaml
import argparse


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


# ------------------------------------------------------------
# Parse the YAML file into a dictionary with two keys:
#   - include (list of files to include)
#   - segments
# ------------------------------------------------------------

def parse_yaml(path, model):
    with open(path, "r") as f:
        cfg = yaml.safe_load(f) or {}

    includes = cfg.get("include", [])
    memory = cfg.get("memory", {})
    sections_cfg = cfg.get("sections", [])

    # Build segment objects
    for name, attrs in memory.items():
        model["segments"][name] = {
            "name": name,
            "origin": attrs.get("origin"),
            "length": attrs.get("length"),
            "sections": [],
        }

    # Attach sections to segments
    for sec in sections_cfg:
        sec_name = sec['name']

        if "name" not in sec:
            die("section missing name")
        if "segment" not in sec:
            die(f"section {sec_name} missing segment")

        seg_name = sec["segment"]
        if seg_name not in model["segments"]:
            die(f"unknown segment '{seg_name}' attached to section {sec_name}")

        section_obj = {
            "name": sec_name,
            "align": sec.get("align"),
            "noload": sec.get("noload", False),
            "nopad": sec.get("nopad", False),
        }

        model["segments"][seg_name]["sections"].append(section_obj)

    model["includes"] += includes
    return model

# ------------------------------------------------------------
# Generate the ASM file that acts as a linker script for Z88DK
# ------------------------------------------------------------

def emit_asm(model):
    out = []
    
    out.append("; This file was auto-generated, do not modify it manually\n\n")

    # Always put the includes first
    for inc in model["includes"]:
        out.append(f'        INCLUDE "{inc}"\n')

    if model["includes"]:
        out.append("\n")

    # Section padding counter
    count = 0

    # Segments and sections
    for seg in model["segments"].values():
        org_needs_output = True if seg["origin"] is not None else False

        # Keep in memory the previous section padding rules
        prev_sec_nopad = False
        for sec in seg["sections"]:

            # If the previous section must not be padded and the current has an alignement
            # constraint, generate a dummy section
            if sec["align"] and prev_sec_nopad:
                out.append(f"        SECTION DUMMY_PAD_{count}\n")
                count += 1

            out.append(f"        SECTION {sec['name']}\n")

            # The ORG directive must come after the name of the first section
            if org_needs_output:
                out.append(f"        ORG {seg['origin']}\n")
                org_needs_output = False

            if sec["align"]:
                out.append(f"        ALIGN {sec['align']}\n")
            
            prev_sec_nopad = sec["nopad"]

        # Skip one line after each segments
        out.append("\n")

    return "".join(out)


def main():
    parser = argparse.ArgumentParser(
        description="Compose multiple Zeal YAML linker scripts into one Z88DK ASM linker file"
    )
    parser.add_argument(
        "yml_files",
        nargs="+",
        help="Input YAML linker files (order matters)",
    )
    parser.add_argument(
        "-o", "--output",
        required=True,
        help="Output ASM file path",
    )

    args = parser.parse_args()

    model = {"includes": [], "segments": {}}

    for yml in args.yml_files:
        model = parse_yaml(yml, model)

    asm = emit_asm(model)
    Path(args.output).write_text(asm)

if __name__ == "__main__":
    main()

