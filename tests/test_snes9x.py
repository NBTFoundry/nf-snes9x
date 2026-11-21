# SPDX-License-Identifier: MPL-2.0
"""Snes9x on the libretro host, under Xvfb, with a small test cartridge made
here (no game is shipped): the game list, a battery save, save states and
the region setting; and the signed package's declaration."""

import os
from pathlib import Path
import re
import select
import shutil
import signal
import socket
import struct
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
APP = Path(os.environ.get("NBT_SNES9X_APP", ROOT / "build/nbt-snes9x-host"))
MGR_DIR = Path(os.environ.get("NBT_MGR_DIR", ROOT.parent / "manager"))

SOUTH, VIEW, MENU, DOWN = 1 << 0, 1 << 6, 1 << 7, 1 << 12
XBOX = 1


def cartridge() -> bytes:
    """32 KiB LoROM with 2 KiB of battery-backed RAM: writes 0x42 to its
    first byte, then loops."""
    rom = bytearray(0x8000)
    code = bytes([0x78, 0x18, 0xFB,  # SEI; CLC; XCE (native mode)
                  0xA9, 0x42,  # LDA #$42
                  0x8F, 0x00, 0x00, 0x70,  # STA $700000 (cartridge RAM)
                  0x80, 0xFE])  # BRA * (forever)
    rom[: len(code)] = code
    rom[0x10] = 0x40  # RTI, for the interrupts
    header = 0x7FC0
    rom[header : header + 21] = b"NBT TEST CARTRIDGE   "
    rom[header + 0x15] = 0x20  # LoROM
    rom[header + 0x16] = 0x02  # ROM, RAM and battery
    rom[header + 0x17] = 0x05  # 32 KiB of ROM
    rom[header + 0x18] = 0x01  # 2 KiB of RAM
    rom[header + 0x19] = 0x01  # North America
    for vector in (0x7FEA, 0x7FEE, 0x7FFA, 0x7FFE):  # NMI and IRQ, native and emulation
        rom[vector : vector + 2] = struct.pack("<H", 0x8010)
    rom[0x7FFC:0x7FFE] = struct.pack("<H", 0x8000)  # reset
    rom[header + 0x1C : header + 0x20] = b"\xff\xff\x00\x00"
    checksum = sum(rom) & 0xFFFF
    rom[header + 0x1C : header + 0x20] = struct.pack("<HH", checksum ^ 0xFFFF, checksum)
    return bytes(rom)


def xvfb():
    r, w = os.pipe()
    proc = subprocess.Popen(
        ["Xvfb", "-displayfd", str(w), "-screen", "0", "1280x480x24", "-nolisten", "tcp"],
        pass_fds=(w,), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.close(w)
    number = b""
    while not number.endswith(b"\n"):
        ready, _, _ = select.select([r], [], [], 10)
        chunk = os.read(r, 1) if ready else b""
        if not chunk:
            break
        number += chunk
    os.close(r)
    return proc, ":" + number.decode().strip()


class App:
    """The emulator, its log (standard error) read by line."""

    def __init__(self, env, pass_fds):
        full = {k: v for k, v in os.environ.items() if not k.startswith("NBT_")}
        full.update(env)
        self.proc = subprocess.Popen([str(APP)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                                     env=full, pass_fds=pass_fds)
        self.lines, self.buf = [], b""

    def wait(self, pattern, timeout=20.0):
        regex, deadline = re.compile(pattern), time.monotonic() + timeout
        while True:
            while b"\n" in self.buf:
                raw, self.buf = self.buf.split(b"\n", 1)
                self.lines.append(raw.decode(errors="replace"))
            for i, line in enumerate(self.lines):
                if regex.search(line):
                    del self.lines[: i + 1]
                    return line
            fd = self.proc.stderr.fileno()
            left = deadline - time.monotonic()
            ready, _, _ = select.select([fd], [], [], max(0.0, left)) if left > 0 else ([], [], [])
            chunk = os.read(fd, 4096) if ready else b""
            if not chunk:
                raise AssertionError(f"no line matching {pattern!r}; saw {self.lines[-20:]!r}")
            self.buf += chunk

    def stop(self):
        if self.proc.poll() is None:
            self.proc.send_signal(signal.SIGTERM)
        _, err = self.proc.communicate(timeout=20)
        self.buf += err
        return self.proc.returncode


@unittest.skipUnless(os.access(APP, os.X_OK), f"{APP} not built")
@unittest.skipUnless(shutil.which("Xvfb"), "Xvfb not installed")
class PlayTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="nbt-snes9x-"))
        self.files, self.data = self.tmp / "files", self.tmp / "data"
        self.files.mkdir(mode=0o700)
        self.data.mkdir(mode=0o700)
        (self.files / "Test Game.sfc").write_bytes(cartridge())
        (self.files / "notes.txt").write_bytes(b"not a game")
        self.x, self.display = xvfb()
        self.pad_app, self.pad = socket.socketpair(socket.AF_UNIX, socket.SOCK_DGRAM)
        self.seq = 0

    def tearDown(self):
        self.pad_app.close()
        self.pad.close()
        self.x.terminate()
        self.x.wait(timeout=5)
        shutil.rmtree(self.tmp, ignore_errors=True)

    def start(self, **settings):
        env = {
            "NBT_LAUNCH": "user", "DISPLAY": self.display, "LIBGL_ALWAYS_SOFTWARE": "1",
            "NBT_NO_AUDIO": "1", "NBT_FILES_DIR": str(self.files), "NBT_DATA_DIR": str(self.data),
            "NBT_BRIDGE_CAPS": "gamepad", "NBT_GAMEPAD_FD": str(self.pad_app.fileno()),
        }
        env.update({"NBT_SETTING_" + k.upper(): v for k, v in settings.items()})
        app = App(env, (self.pad_app.fileno(),))
        self.addCleanup(lambda: app.proc.poll() is None and app.proc.kill())
        app.wait(r"core Snes9x ")
        return app

    def press(self, buttons=0, hold=0.15):
        self.seq += 1
        self.pad.send(struct.pack("<BBBBIIhhhhHH", 1, 1, 1, XBOX, self.seq, buttons, 0, 0, 0, 0, 0, 0))
        time.sleep(hold)

    def tap(self, buttons):
        self.press(buttons)
        self.press(0)

    def menu(self, downs):
        """The pause menu (View + Menu), `downs` items down, chosen."""
        self.tap(VIEW | MENU)
        for _ in range(downs):
            self.tap(DOWN)
        self.tap(SOUTH)

    def test_a_game_runs_saves_and_restores_a_state(self):
        app = self.start()
        self.press(0)
        self.tap(SOUTH)  # the only game; notes.txt is not one
        app.wait(r"game Test Game\.sfc: 256x2\d\d, 60\.\d+ fps")
        self.menu(1)  # Save state
        app.wait(r"State saved in slot 1")
        state = self.data / "states" / "Test Game.sfc.state1"
        self.assertGreater(state.stat().st_size, 1000)
        self.menu(2)  # Load state
        app.wait(r"State of slot 1 loaded")
        self.assertEqual(app.stop(), 0)
        save = (self.data / "saves" / "Test Game.sfc.srm").read_bytes()
        self.assertEqual((len(save), save[0]), (2048, 0x42))
        self.assertEqual((self.data / "last-game").read_bytes(), b"Test Game.sfc")

    def test_the_region_setting_reaches_the_core(self):
        app = self.start(region="pal")
        self.press(0)
        self.tap(SOUTH)
        app.wait(r"game Test Game\.sfc: 256x2\d\d, 50\.\d+ fps")
        self.assertEqual(app.stop(), 0)


class PackageTest(unittest.TestCase):
    def test_the_package_declares_files_and_its_settings(self):
        verify = MGR_DIR / "build" / "nbt-verify"
        if not (MGR_DIR / "tools/package.py").exists() or not verify.exists():
            self.skipTest("the manager's tools/package.py or build/nbt-verify is missing")
        if not shutil.which("openssl"):
            self.skipTest("openssl is missing")
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            key, public = tmp / "app.key", tmp / "app.pub"
            subprocess.run(["openssl", "genrsa", "-out", key, "3072"], check=True, capture_output=True)
            subprocess.run(["openssl", "rsa", "-in", key, "-pubout", "-out", public], check=True,
                           capture_output=True)
            # A stand-in for the module: ARM ET_DYN with the SDK's NBT ABI note.
            binary = tmp / "stand-in.so"
            note = struct.pack("<III", 4, 12, 1) + b"NBT\0" + struct.pack("<III", 1, 1, 1)
            elf = bytearray(52)
            elf[:7] = b"\x7fELF\x01\x01\x01"
            struct.pack_into("<HHI", elf, 16, 3, 40, 1)
            struct.pack_into("<I", elf, 28, 52)
            struct.pack_into("<HHH", elf, 40, 52, 32, 1)
            phdr = struct.pack("<IIIIIIII", 4, 84, 0, 0, len(note), len(note), 4, 4)
            binary.write_bytes(bytes(elf) + phdr + note)
            subprocess.run(["make", "-s", "-C", str(ROOT), "package", f"BUILD_DIR={tmp}",
                            f"PACKAGE_INPUT={binary}", f"APP_KEY={key}", f"NBT_MGR_DIR={MGR_DIR}",
                            "APP_VERSION=1.63.0"], check=True, capture_output=True)
            package = tmp / "snes9x-1.63.0.nbt"
            out = subprocess.run([str(verify), str(package), str(public), "snes9x", "nbt_6.5_armv7"],
                                 check=True, capture_output=True, text=True).stdout
            self.assertIn("app=snes9x\n", out)
            self.assertIn("bridge=1.7\n", out)
            self.assertIn("bridge-uses=show,controller,files,runner\n", out)
            self.assertIn("bridge-optional=status,live-settings,gamepad\n", out)
            raw = package.read_bytes()
            manifest = raw[24 : 24 + int.from_bytes(raw[8:12], "big")].decode("ascii")
            self.assertIn("bridge-files=sfc,smc,fig,swc|16|1024\n", manifest)
            for setting in ("aspect|Aspect|4-3|4-3,pixel,full", "region|Region|auto|auto,ntsc,pal",
                            "frameskip|Frame skip|off|off,auto,1,2"):
                self.assertIn(f"setting={setting}\n", manifest)


if __name__ == "__main__":
    unittest.main()
