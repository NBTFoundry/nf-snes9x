// SPDX-License-Identifier: MPL-2.0
/* Snes9x on NBT Manager: the upstream libretro core, linked statically, on
 * the SDK's libretro host (game list, saves, states, pause menu, controls). */
#include <stddef.h>

#include "controls.hpp"
#include "nbt/retro/host.hpp"

namespace {

/* The files NBT Manager accepts for Snes9x (bridge-files in the Makefile). */
const char* const kExtensions[] = {"sfc", "smc", "fig", "swc", NULL};

/* Manager settings feeding the core's variables: setting value, core value. */
const char* const kRegion[] = {"auto", "auto", "ntsc", "ntsc", "pal", "pal", NULL};
const nbt::retro::VariableMap kVariables[] = {{"region", "snes9x_region", kRegion}};

/* A cartridge holds at most 8 MiB (ExHiROM); the manager allows 16. */
const size_t kMaxRomBytes = 16 * 1024 * 1024;

}  // namespace

int main(int argc, char** argv) {
  const nbt::retro::HostConfig config = {"snes9x",
                                         "Snes9x",
                                         "Super Nintendo",
                                         kExtensions,
                                         &snes9x::controls(),
                                         kVariables,
                                         sizeof(kVariables) / sizeof(kVariables[0]),
                                         4.0f / 3.0f,
                                         kMaxRomBytes,
                                         false /* no BIOS files */,
                                         NULL /* each game one file: no game folders */};
  return nbt::retro::run(argc, argv, config);
}
