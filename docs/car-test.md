<!-- SPDX-License-Identifier: MPL-2.0 -->
# Car test: Snes9x before a release

Parked, ignition on. About 30 minutes, all from the phone: no adapter, no
computer.

Run it on a candidate before tagging a release, and whenever the car-side
behaviour changed. Snes9x is a **module**: NBT Manager's `nbt-runner` loads it
into its own process and draws and plays its sound for it.

## What you need

- NBT Manager 0.3.1 or later on the car, and its phone app, paired.
- From the kit folder: the candidate `snes9x-<version>.nbt`, a second one with
  a higher sequence for part C, and their `SHA256SUMS` file. Copy them to the
  phone.
- A Super Nintendo game you own (`.sfc` or `.smc`), on the phone or a USB
  stick. One with a busy scene (Mode 7, many sprites) shows speed best.
- A USB gamepad (Xbox or DualShock 4 / DualSense), for B.4.

## A. Install

1. In the phone app's library, add the candidate and open it. Under the file
   name: **Snes9x** (the version), **Project: Snes9x
   (https://github.com/snes9xgit/snes9x)**, **Licence: Snes9x licence
   (non-commercial)**, then the text, ending with the repository's address.
2. Send it to the car (an install, or an update of **snes9x**) and approve on
   the car. The health check (about 10 s) must pass.
3. Hold the push on **snes9x**: 7 settings (Aspect, Filter, Region, Frame
   skip, Sound, Show FPS, Debug log). Set **Show FPS: on**.
4. Add the game: in the phone app, **snes9x** → **Files** → **Add files**; or
   with the USB stick in, hold the push on **snes9x** → **Files** → **Import
   from a USB stick**.

## B. Play

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

## C. Stop, start again, update

1. Hold the push on **snes9x** → **Stop**: the screen returns. Start it again.
2. While the game runs, send the second package from the phone and approve.
   The update stops the game, runs the health check and installs.
3. Start **snes9x** and the same game: the save and states are still there.

## Logs

The phone app: **snes9x** → **Show log** → **Share** (more with **Debug log:
on**). A crash shows as `Process … terminated SIG… ip=…` and the application
ending by a signal: copy both lines. For more, the phone's **Collect
everything** (Install NBT Manager on a car › More tools, over the Wi-Fi ENET
adapter).

## Back

Uninstall **snes9x** from the car's page, or install the last release from
GitHub (a test package with a lower sequence is refused).

## Report

| Step | Result | Notes |
| --- | --- | --- |
| A.1 information shown | | |
| A.2 install or update + health check | | |
| A.3 7 settings | | |
| A.4 game added (phone or USB) | | |
| B.1 game starts, sound, FPS (busy scene) | | |
| B.2 iDrive controls | | |
| B.3 states; in-game save kept after quit | | |
| B.4 gamepad named, positions, unplug | | |
| B.5 filter from the phone, live | | |
| C.1 stop, start again | | |
| C.2 update while running | | |
| C.3 saves and states kept | | |

Add the car's software version, the game (and its region) and the pad model.
