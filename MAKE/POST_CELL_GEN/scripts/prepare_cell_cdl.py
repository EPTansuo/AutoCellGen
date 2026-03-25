#!/usr/bin/env python3

import argparse
from pathlib import Path


def extract_subckt(lines, source_cell):
    capture = False
    block = []
    for line in lines:
        stripped = line.strip()
        upper = stripped.upper()
        if upper.startswith(".SUBCKT"):
            parts = stripped.split()
            capture = len(parts) >= 2 and parts[1] == source_cell
        if capture:
            block.append(line)
        if capture and upper.startswith(".ENDS"):
            break
    if not block:
        raise RuntimeError(f"Could not find .SUBCKT {source_cell}")
    return block


def rename_subckt(block, target_cell):
    renamed = []
    for index, line in enumerate(block):
        stripped = line.strip()
        upper = stripped.upper()
        if index == 0 and upper.startswith(".SUBCKT"):
            parts = stripped.split()
            parts[1] = target_cell
            renamed.append(" ".join(parts) + "\n")
            continue
        if upper.startswith(".ENDS"):
            parts = stripped.split()
            if len(parts) > 1:
                parts[1] = target_cell
                renamed.append(" ".join(parts) + "\n")
            else:
                renamed.append(".ENDS\n")
            continue
        renamed.append(line if line.endswith("\n") else line + "\n")
    return renamed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--target-cell", required=True)
    parser.add_argument("--source-cell")
    args = parser.parse_args()

    input_path = Path(args.input)
    lines = input_path.read_text().splitlines(True)

    subckts = []
    for line in lines:
        stripped = line.strip()
        if stripped.upper().startswith(".SUBCKT"):
            parts = stripped.split()
            if len(parts) >= 2:
                subckts.append(parts[1])

    if args.source_cell:
        source_cell = args.source_cell
    elif len(subckts) == 1:
        source_cell = subckts[0]
    elif args.target_cell in subckts:
        source_cell = args.target_cell
    else:
        raise RuntimeError(
            f"Input CDL contains multiple subckts {subckts}; pass --source-cell to choose one"
        )

    block = extract_subckt(lines, source_cell)
    renamed = rename_subckt(block, args.target_cell)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("".join(renamed))


if __name__ == "__main__":
    main()
