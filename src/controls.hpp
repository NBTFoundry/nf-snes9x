// SPDX-License-Identifier: MPL-2.0
/* The Super Nintendo pad on a USB gamepad, the iDrive controller and the
 * desktop keyboard. */
#ifndef NBT_SNES9X_CONTROLS_HPP
#define NBT_SNES9X_CONTROLS_HPP

#include "nbt/frontend/pad_profiles.hpp"

namespace snes9x {

/* Each pad family has the SNES pad's layout, button for button by position:
 * the bottom face button is B, the right one A, the left one Y, the top one
 * X. Actions are RETRO_DEVICE_ID_JOYPAD_* of port 0. */
const nbt::frontend::Profiles& controls();

}  // namespace snes9x

#endif /* NBT_SNES9X_CONTROLS_HPP */
