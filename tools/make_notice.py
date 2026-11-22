#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Writes legal/NOTICE.txt: the notices the application's module carries.

Ours (MPL-2.0), Snes9x's licence (the module leaves out its LGPL NTSC
filter: src/compat/snes_ntsc_off.c stands in for it), the third-party notices of the NBT App SDK it links (NBT_SDK_DIR, default
../sdk), and picolibc, which the NBT toolchain's runtime links statically
(NBT_TOOLCHAIN, default the SDK's installed release). Run again when the
pin, the SDK or the toolchain changes.
"""
import os
from pathlib import Path
import re
import subprocess
import sys

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


def toolchain() -> Path:
    if os.environ.get("NBT_TOOLCHAIN"):
        return Path(os.environ["NBT_TOOLCHAIN"])
    version = re.search(r"^NBT_TOOLCHAIN_VERSION := (\S+)", (SDK / "module/flags.mk").read_text(), re.M)
    return SDK / "toolchain" / f"nbt-toolchain-{version.group(1)}"


def main():
    runtime = toolchain() / "share/licenses/picolibc"
    if not runtime.is_dir():
        sys.exit(f"no picolibc notices in {runtime}: set NBT_TOOLCHAIN")
    sdk_notices = subprocess.run([sys.executable, str(SDK / "tools/third_party_notices.py")],
                                 check=True, capture_output=True, text=True).stdout
    parts = [
        HEADER,
        "Head-unit risk and disclaimer\n\n" + (ROOT / "DISCLAIMER.md").read_text().split("\n", 1)[1],
        "MPL-2.0: this application and the NBT App SDK (https://github.com/NBTFoundry/sdk)\n\n"
        + (ROOT / "LICENSES/MPL-2.0.txt").read_text(),
        "Snes9x 1.63, the emulator (third_party/snes9x)\nhttps://github.com/snes9xgit/snes9x\n\n"
        + (CORE / "LICENSE").read_text(),
        "libretro.h and libretro-common headers in Snes9x's libretro port (third_party/snes9x/libretro)\n"
        "Copyright (C) 2010-2018 The RetroArch team; MIT License, the text below with libretro.h.\n",
        sdk_notices,
        "picolibc, the C library of the NBT toolchain's runtime, linked statically "
        "(https://github.com/picolibc/picolibc)\n\n"
        + (runtime / "COPYING.picolibc").read_text() + RULE.lstrip("\n")
        + "picolibc's newlib-derived parts\n\n" + (runtime / "COPYING.NEWLIB").read_text(),
    ]
    text = "\n\n" + RULE.join(p.rstrip("\n") + "\n" for p in parts)
    (ROOT / "legal/NOTICE.txt").write_text(text)
    print(f"legal/NOTICE.txt: {len(parts)} sections")


if __name__ == "__main__":
    main()
