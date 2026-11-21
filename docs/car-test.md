<!-- SPDX-License-Identifier: MPL-2.0 -->
# Car test: Snes9x, the QNX build and the runner build

Parked, ignition on. About 30 minutes. Keep SSH/ENET recovery at hand.

Two builds of Snes9x 1.63.0, played on the same game to compare them:

- `snes9x-1.63.0-qnx2.nbt` (sequence 3): the form of the GitHub release, a
  QNX executable.
- `snes9x-1.63.0-module2.nbt` (sequence 4): built without the QNX SDP, as a
  module that `nbt-runner` (carried in the package) loads into its own
  process. The first module in the car. It is installed as an update of the
  first.

The first run (`-qnx`/`-module`) showed the game list with the runner build,
then stopped with SIGBUS as the game started: the core read 16-bit values at
odd addresses, which the head unit refuses. The runner build now reads those
byte by byte (`make test-align` checks it on the desktop). Play the QNX build
first this time (B), then update (C).

## What you need

- NBT Manager from test kit **dev120** and its phone app, paired.
- From the kit folder: `snes9x-1.63.0-qnx2.nbt` and `snes9x-1.63.0-module2.nbt`
  (`snes9x-1.63.0-2-SHA256SUMS.txt`). Copy both to the phone.
- A Super Nintendo game you own (`.sfc` or `.smc`), on the phone or a USB
  stick. One with a busy scene (Mode 7, many sprites) shows speed best.
- A USB gamepad (Xbox or DualShock 4 / DualSense), for B.4.

## A. Install the QNX build

1. On the phone: import `snes9x-1.63.0-qnx2.nbt`, send it to the car and
   approve (an update of the runner build installed now). The health check (about 10 s) must pass.
2. Hold the push on **snes9x**: 7 settings (Aspect, Filter, Region, Frame
   skip, Sound, Show FPS, Debug log). Set **Show FPS: on**.
3. Add the game: in the phone app, **snes9x** → **Files** → **Add files**; or
   with the USB stick in, hold the push on **snes9x** → **Files** → **Import
   from a USB stick**.

## B. Play the QNX build

1. Select **snes9x**: the game list shows the game. Start it: title screen
   with sound. Note the FPS (60 NTSC, 50 PAL) in the busy scene.
2. iDrive controller: tilt is the D-pad, push A, BACK tap B, favourite keys 1
   and 2 Y and X, the knob L and R, MEDIA Select, OPTION Start, MENU the pause
   menu.
3. Pause menu: **Save state**, play on, **Load state**: back where saved.
   Save in the game itself, quit with a long BACK hold, start again: the save
   is there.
4. Plug the gamepad in: a notice names it, each button sits where the Super
   Nintendo pad has it. Unplug it: the iDrive controller plays again.
5. While playing, change **Filter** from the phone: it applies at once.

## C. The runner build

1. While the game runs, send `snes9x-1.63.0-module2.nbt` from the phone and
   approve. The update stops the game, runs the health check and installs.
2. Start **snes9x** and the same game: the save and states are still there.
   In the same busy scene, note the FPS against B.1, then check sound and the
   controls of B.2 quickly.
3. Hold the push on **snes9x** → **Stop**: the screen returns. Start it again.

## D. Over SSH (optional)

- `pidin arg | grep snes9x`: one process, `…/apps/snes9x/bin/app`. With the
  runner build that is the runner, with the module loaded inside it from
  `.nbt-payload-<pid>` in the data folder.
- `kill -9 <pid>`: the manager shows it stopped; start it again: it runs.

## Logs

The phone app: **snes9x** → **Show log** → **Share** (more with **Debug log:
on**). The runner build adds the runner's lines (`[nbt-runner] …`). A crash
shows as `Process … terminated SIG… ip=…` and the application ending by a
signal: copy both lines.

## Back

Uninstall **snes9x**, or install the GitHub release v1.63.0 (sequence
1063000) over it.

## Report

| Step | Result | Notes |
| --- | --- | --- |
| A.1 install QNX build + health check | | |
| A.2 7 settings | | |
| A.3 game added (phone or USB) | | |
| B.1 game starts, sound, FPS (busy scene) | | |
| B.2 iDrive controls | | |
| B.3 states; in-game save kept after quit | | |
| B.4 gamepad named, positions, unplug | | |
| B.5 filter from the phone, live | | |
| C.1 update to the runner build while running | | |
| C.2 same game: saves kept, FPS vs B.1, sound, controls | | |
| C.3 stop, start again | | |
| D kill -9, start again | | |

Add the car's software version, the game (and its region) and the pad model.
