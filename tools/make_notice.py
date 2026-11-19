#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Writes legal/NOTICE.txt: the notices a binary of this application carries.

Ours (MPL-2.0), Snes9x's licence and the LGPL of its NTSC filter, then the
third-party notices of the NBT App SDK it links (NBT_SDK_DIR, default
../sdk). Run again when a dependency changes.
"""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SDK = Path(os.environ.get("NBT_SDK_DIR", ROOT.parent / "sdk"))
CORE = ROOT / "third_party/snes9x"
RULE = "\n" + "=" * 72 + "\n\n"

HEADER = """NBTFoundry

NBTFoundry nf-snes9x
Copyright (c) 2026 Fabien Poussin
Original software: MPL-2.0. You may redistribute and modify it under that license.
This software comes WITHOUT ANY WARRANTY, to the extent permitted by law.
Original NBTFoundry artwork: MPL-2.0. Trademark rights are separate.
Source: https://github.com/NBTFoundry/nf-snes9x
When redistributing binaries, include applicable notices and provide the source required by the component licenses.

The application's binary contains Snes9x, whose licence permits non-commercial
use and distribution only: the binary, as a whole, may be distributed only on
Snes9x's terms below. No game is included.
"""


def sdk_third_party():
    """The SDK's notices after its own header, disclaimer and MPL-2.0 text."""
    sections = (SDK / "legal/NOTICE.txt").read_text().split("=" * 72)
    keep = [s.strip("\n") for s in sections
            if s.strip() and not s.strip().startswith(("NBTFoundry", "Head-unit risk", "MPL-2.0", "Exhibit"))]
    # The MPL text spans several sections (its own rules): only those naming a component stay.
    return [s for s in keep if " used by " in s.splitlines()[0]]


def main():
    parts = [
        HEADER,
        "Head-unit risk and disclaimer\n\n" + (ROOT / "DISCLAIMER.md").read_text().split("\n", 1)[1],
        "MPL-2.0\n\n" + (ROOT / "LICENSES/MPL-2.0.txt").read_text(),
        "Snes9x 1.63, the emulator (third_party/snes9x)\nhttps://github.com/snes9xgit/snes9x\n\n"
        + (CORE / "LICENSE").read_text(),
        "snes_ntsc, Snes9x's NTSC filter (third_party/snes9x/filter/snes_ntsc.c)\n"
        "Copyright (C) 2006-2007 Shay Green. Used in Snes9x under the GNU LGPL 2.1:\n\n"
        + (CORE / "filter/snes_ntsc-license.txt").read_text(),
        "libretro.h and libretro-common headers in Snes9x's libretro port (third_party/snes9x/libretro)\n"
        "Copyright (C) 2010-2018 The RetroArch team; MIT License, the text below with libretro.h.\n",
    ] + [s + "\n" for s in sdk_third_party()]
    text = "\n\n" + RULE.join(p.rstrip("\n") + "\n" for p in parts)
    (ROOT / "legal/NOTICE.txt").write_text(text)
    print(f"legal/NOTICE.txt: {len(parts)} sections")


if __name__ == "__main__":
    main()
