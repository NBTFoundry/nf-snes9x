#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Lists the C++ runtime symbols a QNX binary imports that the head unit's
libraries do not define, and fails when there are any.

The toolchain's libstdc++ carries no symbol versions, so GLIBCXX_* checks see
nothing: a symbol of a newer libstdc++ (GCC 4.9's __throw_out_of_range_fmt,
say) only shows against the old library itself.

Usage: check_qnx_imports.py <nm> <binary> <library>...
"""
import subprocess
import sys


def symbols(nm, path, defined):
    flag = "--defined-only" if defined else "--undefined-only"
    out = subprocess.run([nm, "-D", flag, path], check=True, capture_output=True, text=True).stdout
    return {line.split()[-1].split("@")[0] for line in out.splitlines() if line.strip()}


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    nm, binary, libraries = sys.argv[1], sys.argv[2], sys.argv[3:]
    known = set()
    for library in libraries:
        known |= symbols(nm, library, True)
    missing = sorted(s for s in symbols(nm, binary, False)
                     if s.startswith(("_Z", "__cxa", "__gxx")) and s not in known)
    if missing:
        names = subprocess.run(["c++filt"], input="\n".join(missing), capture_output=True,
                               text=True).stdout
        print("C++ runtime symbols the head unit lacks:\n" + names.rstrip())
        sys.exit(1)
    print(f"OK: every C++ runtime symbol {binary} imports is in {', '.join(libraries)}")


if __name__ == "__main__":
    main()
