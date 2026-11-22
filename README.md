<!-- SPDX-License-Identifier: MPL-2.0 -->
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.svg">
    <img src="docs/assets/logo-light.svg" alt="NBTFoundry" height="44">
  </picture>
</p>

<h1 align="center">Snes9x for NBT Manager</h1>

> **Warning: installing or modifying this software can brick your head unit. Recovery may require professional service or replacement, at your expense. Provided AS IS; use at your own risk, subject to applicable law.** [Read the risk and liability disclaimer](DISCLAIMER.md).

<p align="center">
  <b>Super Nintendo games on the iDrive screen,</b><br>
  played with a USB gamepad laid out like the original pad, or the iDrive controller.
</p>

Snes9x 1.63's libretro core, unmodified, on the NBT App SDK's libretro host:
the frame scaled to the car's panel, sound through the car's speakers, battery
saves, save states and a pause menu. Games come from the NBT Manager phone app
or a USB stick, copied to the head unit's hard disk. Installed and launched
through NBT Manager.

**Supported head units:** BMW NBT Evo (iDrive 6). Support for the earlier NBT
may come later.

Part of [NBTFoundry](https://github.com/NBTFoundry):
[manager](https://github.com/NBTFoundry/manager) ·
[sdk](https://github.com/NBTFoundry/sdk) ·
[mobile-app](https://github.com/NBTFoundry/mobile-app) ·
[installer](https://github.com/NBTFoundry/installer) ·
[nf-doom](https://github.com/NBTFoundry/nf-doom)

Not affiliated with or endorsed by BMW AG or Nintendo. BMW, iDrive and NBT are
trademarks of BMW AG; Super Nintendo and Super NES are trademarks of Nintendo.
No game is included: use only games you own.

## Adding games

Snes9x takes `.sfc`, `.smc`, `.fig` and `.swc` files of up to 16 MiB, 1 GiB in
all (NBT Manager's `files` capability). Zipped games are not read.

- **From the phone:** the NBT Manager app, the car, Snes9x, **Files**, **Add
  files**. The files are stored at once; the phone asks before deleting one.
- **From a USB stick:** on the car, hold the push on Snes9x in NBT Manager, then
  **Files** › **Import from a USB stick**: every game found (in folders too) is
  listed, one or all of them copied to the car.

## Playing

Snes9x opens on its game list, the last game played focused. In a game, the
pause menu has Resume, Save state, Load state, the slot (1 to 4), Reset,
Choose another game and Quit. Battery saves are written when they change (at
most every 10 seconds) and on leaving; they and the states stay in Snes9x's
data folder across updates.

## Controls

Bindings are chosen for the pad plugged in, by its family; there is nothing to
set. Each face button is where the Super Nintendo pad has it, so a game plays
as on the original: the bottom button is B, the right one A.

| SNES | Xbox | DualShock 4 / DualSense | iDrive controller | Desktop |
| --- | --- | --- | --- | --- |
| D-pad | D-pad or left stick | D-pad or left stick | Tilt | Arrows |
| B (bottom) | A | Cross | BACK, tap | Z |
| A (right) | B | Circle | Push | X |
| Y (left) | X | Square | Favourite key 1 | A |
| X (top) | Y | Triangle | Favourite key 2 | S |
| L / R | LB / RB, or LT / RT | L1 / R1, or L2 / R2 | Turn the knob left / right | Q / W |
| Select | View | Share / Create | MEDIA | Right Shift |
| Start | Menu | Options | OPTION | Return |
| Pause menu | Xbox button, or View + Menu | PS button, or Share / Create + Options | MENU, or BACK held | Escape |
| Quit | from the menu | from the menu | BACK, long hold | from the menu |

In the menus the D-pad, left stick, knob or tilts move, the bottom button
(push) chooses and the right button (BACK) goes back; LB and RB (L1, R1) jump
ten games. The menus name the buttons of the pad in use, and a notice says
when a pad is plugged in or removed: the iDrive controller then plays. The
knob holds L or R for 150 ms per detent. Which pads are supported is up to
NBT Manager (`NBTFoundry/manager: docs/gamepad-bridge.md`).

## Settings

Changed from the phone app or NBT Manager's settings page; they apply at once.

| Setting | Choices | Default |
| --- | --- | --- |
| Aspect | 4-3 (the TV's shape), pixel (whole multiples), full | 4-3 |
| Filter | sharp (crisp pixels, smoothed edges), smooth, nearest | sharp |
| Region | auto, ntsc (60 Hz), pal (50 Hz) | auto |
| Frame skip | off, auto (while running late), 1, 2 | off |
| Sound | on, off | on |
| Show FPS | off, on | off |
| Debug log | off, on | off |

## Bridge

The package carries the module (built without the QNX SDP, run by NBT
Manager's `nbt-runner`) and declares bridge 1.7: `show`, `controller`, `files`
and `runner` required,
`status`, `live-settings` and `gamepad` optional, and the files policy
`sfc,smc,fig,swc|16|1024`. Snes9x reports the game played as its status. NBT
Manager keeps its standard error as its log (shown, shared and cleared from the
phone app); the Debug log setting adds tracing and the core's debug messages.

## Build

Needs the NBT App SDK next to this repository (`../sdk`, or `NBT_SDK_DIR`),
gcc, Python 3, and the X11, EGL and GLESv2 development files; Xvfb for the
tests. `git submodule update --init` fetches Snes9x.

```sh
make -j"$(nproc)" host test test-asan check-static-init   # host binary and tests
./build/nbt-snes9x-host                                   # play on the desktop (X11)
```

The desktop build lists the games in `NBT_FILES_DIR` and keeps saves in
`NBT_DATA_DIR` (the current folder without it):
`NBT_FILES_DIR=~/snes NBT_DATA_DIR=/tmp/snes9x ./build/nbt-snes9x-host`. The
tests make a small cartridge of their own; no game is needed.

Head unit (QNX 6.5 ARMv7): the module, built with the SDK's open toolchain
(`make -C ../sdk toolchain` once) and nothing from the QNX SDP. NBT Manager
0.2.0 and later (bridge 1.7) run it with their `nbt-runner`:

```sh
make -j"$(nproc)" module                                       # build/nbt-snes9x.so
make APP_KEY=/path/to/apps-signing-key.pem package             # build/snes9x-<version>.nbt
```

`package` signs the module with NBT Manager's packer
(`../manager/tools/package.py`, or `NBT_MGR_DIR`), described by
`release/package.args`. It also carries what the phone app shows before an install
(the Snes9x version, the project, the licence, notices); `make package-args`
writes the version the pin builds, and `make test` fails when it lags.
Pushing a tag `vX.Y.Z` releases a signed package from CI
(`.github/workflows/release.yml`, NBT Manager's `app-release.yml` with
`qnx: false`: a plain runner, no private image), with package sequence
`X*1000000 + Y*1000 + Z`.

The QNX SDP build stays for comparisons on the car (`make QNX_ENV=…
QNX_SCREEN_LIBDIR=… qnx qnx-check`, the QNX 6.5 SP1 toolchain); packages do not
carry it.

Built with the 6.6 toolchain, the binary imports `_Sinx` from `libm`, which the
car's QNX 6.5 SP1 lacks; the SP1 toolchain's headers do not inline it.

### Snes9x on the QNX toolchain

Upstream's libretro source list (`libretro/Makefile.common`) builds as C++11
with gcc 4.8.3 or 4.9.3, unmodified; `src/compat/` fills the toolchain's gaps:

- `snes9x_qnx.h`, included before each core source: QNX's `<math.h>` brings
  Dinkumware type traits that clash with libstdc++'s unless those come first;
  it declares `trunc` in `std` only (6.6), or only with `_HAS_C9X` (6.5); this
  libstdc++ has no `std::to_string`.
- qcc defines `__EXCEPTIONS` even with `-fno-exceptions`, which turns
  libstdc++'s `__try`/`__catch` into real ones: the build undefines it.
- `libstdcxx_qnx.cpp`: `std::__throw_out_of_range_fmt`, which GCC 4.9's
  headers call and the head unit's libstdc++ (6.0.13) lacks. `qnx-check`
  compares every C++ runtime symbol the binary imports with that library
  (`tools/check_qnx_imports.py`): its symbols carry no versions, so a
  `GLIBCXX_3.4.14` check alone cannot see them.

Seven core sources have static constructors (`apu`, `bml`, `controls`,
`globals`, `sdsp`, `smp`, `spc7110`), run by the loader before `main`; our own
objects have none (`check-static-init`).

## To confirm on the head unit

- Full speed with sound (Show FPS): otherwise Frame skip, then the lighter
  `libretro/snes9x2010` core in place of upstream, with the same application.
- The core's static constructors run under the head unit's loader.
- The profile follows a pad plugged in and out; the iDrive controller plays
  without one.

## Layout

| Path | Contents |
| --- | --- |
| `third_party/snes9x/` | Snes9x 1.63, unmodified (submodule) |
| `src/main.cpp` | The application: the SDK's libretro host with Snes9x's settings |
| `src/controls.*` | The SNES layout for each pad family, the iDrive controller and the keyboard |
| `src/compat/` | QNX toolchain gaps (above) |
| `tests/` | Controls unit test (`controls_test.cpp`), play and package tests (`test_snes9x.py`) |
| `tools/` | The QNX import check; `make_notice.py` writes `legal/NOTICE.txt` |

## License

Copyright (c) 2026 Fabien Poussin. Original code, tests, build scripts and
documentation are licensed under **MPL-2.0**; see [LICENSE](LICENSE).

Snes9x keeps its own licence ([LICENSES/LicenseRef-Snes9x.txt](LICENSES/LicenseRef-Snes9x.txt)):
non-commercial use and distribution only. The application's binary contains it
and may be distributed only on those terms. Original NBTFoundry logos and
artwork are MPL-2.0; copyright permission for artwork does not grant trademark
rights or imply endorsement by BMW AG or Nintendo.

See [legal/README.md](legal/README.md) for third-party license notices.
