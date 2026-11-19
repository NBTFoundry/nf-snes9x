// SPDX-License-Identifier: MPL-2.0
/* The SNES layout on every input: each pad family by position, the iDrive
 * controller and the desktop keyboard (README, Controls). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "controls.hpp"
#include "libretro.h"
#include "nbt/app/video.hpp"
#include "nbt/frontend/hints.hpp"

using nbt::frontend::PadMapper;

namespace {

#define CHECK(cond)                                                   \
  do {                                                                \
    if (!(cond)) {                                                    \
      fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); \
      exit(1);                                                        \
    }                                                                 \
  } while (0)

/* Only `action` of the joypad's 16 is held (-1: none). */
bool only(const PadMapper& m, int action) {
  for (int id = 0; id < 16; ++id) {
    if (m.held(id) != (id == action)) return false;
  }
  return true;
}

nbt_gamepad_wire_state pad(uint32_t buttons, unsigned family) {
  nbt_gamepad_wire_state s;
  memset(&s, 0, sizeof(s));
  s.connected = 1;
  s.family = static_cast<uint8_t>(family);
  s.buttons = buttons;
  return s;
}

struct Expect {
  uint32_t control;
  int action;
};

void test_pads() {
  const Expect buttons[] = {{NBT_GAMEPAD_SOUTH, RETRO_DEVICE_ID_JOYPAD_B},
                            {NBT_GAMEPAD_EAST, RETRO_DEVICE_ID_JOYPAD_A},
                            {NBT_GAMEPAD_WEST, RETRO_DEVICE_ID_JOYPAD_Y},
                            {NBT_GAMEPAD_NORTH, RETRO_DEVICE_ID_JOYPAD_X},
                            {NBT_GAMEPAD_LB, RETRO_DEVICE_ID_JOYPAD_L},
                            {NBT_GAMEPAD_RB, RETRO_DEVICE_ID_JOYPAD_R},
                            {NBT_GAMEPAD_VIEW, RETRO_DEVICE_ID_JOYPAD_SELECT},
                            {NBT_GAMEPAD_MENU, RETRO_DEVICE_ID_JOYPAD_START},
                            {NBT_GAMEPAD_UP, RETRO_DEVICE_ID_JOYPAD_UP},
                            {NBT_GAMEPAD_DOWN, RETRO_DEVICE_ID_JOYPAD_DOWN},
                            {NBT_GAMEPAD_LEFT, RETRO_DEVICE_ID_JOYPAD_LEFT},
                            {NBT_GAMEPAD_RIGHT, RETRO_DEVICE_ID_JOYPAD_RIGHT},
                            {NBT_GAMEPAD_LS, -1},
                            {NBT_GAMEPAD_RS, -1}};
  for (unsigned family = 0; family <= NBT_GAMEPAD_FAMILY_MAX; ++family) {
    PadMapper* m = new PadMapper(snes9x::controls());
    uint64_t now = 0;
    for (size_t i = 0; i < sizeof(buttons) / sizeof(buttons[0]); ++i) {
      m->gamepad(pad(buttons[i].control, family), ++now);
      CHECK(only(*m, buttons[i].action));
      m->gamepad(pad(0, family), ++now);
      CHECK(only(*m, -1));
    }
    /* The left stick is the D-pad; the triggers are L and R. */
    nbt_gamepad_wire_state s = pad(0, family);
    s.lx = -20000;
    m->gamepad(s, ++now);
    CHECK(only(*m, RETRO_DEVICE_ID_JOYPAD_LEFT));
    s.lx = 0;
    s.lt = 40000;
    m->gamepad(s, ++now);
    CHECK(only(*m, RETRO_DEVICE_ID_JOYPAD_L));
    s.lt = 0;
    s.rt = 40000;
    m->gamepad(s, ++now);
    CHECK(only(*m, RETRO_DEVICE_ID_JOYPAD_R));
    /* The menu: View and Menu together, or the Xbox / PS button. */
    m->gamepad(pad(0, family), ++now);
    m->gamepad(pad(NBT_GAMEPAD_VIEW | NBT_GAMEPAD_MENU, family), ++now);
    CHECK(m->poll(now) == nbt::frontend::kCommandMenu);
    m->gamepad(pad(0, family), ++now);
    m->gamepad(pad(NBT_GAMEPAD_GUIDE, family), ++now);
    CHECK(m->poll(now) == nbt::frontend::kCommandMenu);
    delete m;
  }
  /* Their names in the menus follow the pad. */
  CHECK(!strcmp(nbt::frontend::pad_button_name(NBT_GAMEPAD_FAMILY_XBOX, NBT_GAMEPAD_SOUTH), "A"));
  CHECK(!strcmp(nbt::frontend::pad_button_name(NBT_GAMEPAD_FAMILY_DUALSENSE, NBT_GAMEPAD_SOUTH),
                "Cross"));
}

void test_controller() {
  PadMapper* m = new PadMapper(snes9x::controls());
  nbt_controller_wire_state c;
  memset(&c, 0, sizeof(c));
  c.connected = 1;
  const Expect keys[] = {{NBT_CONTROLLER_PUSH, RETRO_DEVICE_ID_JOYPAD_A},
                         {NBT_CONTROLLER_TILT_UP, RETRO_DEVICE_ID_JOYPAD_UP},
                         {NBT_CONTROLLER_TILT_DOWN, RETRO_DEVICE_ID_JOYPAD_DOWN},
                         {NBT_CONTROLLER_TILT_LEFT, RETRO_DEVICE_ID_JOYPAD_LEFT},
                         {NBT_CONTROLLER_TILT_RIGHT, RETRO_DEVICE_ID_JOYPAD_RIGHT},
                         {NBT_CONTROLLER_MEDIA, RETRO_DEVICE_ID_JOYPAD_SELECT},
                         {NBT_CONTROLLER_OPTION, RETRO_DEVICE_ID_JOYPAD_START},
                         {NBT_CONTROLLER_FAVOURITE(0), RETRO_DEVICE_ID_JOYPAD_Y},
                         {NBT_CONTROLLER_FAVOURITE(1), RETRO_DEVICE_ID_JOYPAD_X}};
  uint64_t now = 0;
  for (size_t i = 0; i < sizeof(keys) / sizeof(keys[0]); ++i) {
    c.keys = keys[i].control;
    const nbt::controller::Event down = {keys[i].control, 0, 0};
    m->controller(c, down, ++now);
    CHECK(only(*m, keys[i].action));
    c.keys = 0;
    const nbt::controller::Event up = {0, keys[i].control, 0};
    m->controller(c, up, ++now);
    CHECK(only(*m, -1));
  }
  /* The knob: a detent holds L or R for 150 ms. */
  const nbt::controller::Event left = {0, 0, -1};
  m->controller(c, left, 100);
  CHECK(only(*m, RETRO_DEVICE_ID_JOYPAD_L));
  m->poll(260);
  CHECK(only(*m, -1));
  /* A BACK tap is B; MENU opens the menu. */
  const nbt::controller::Event none = {0, 0, 0};
  c.keys = NBT_CONTROLLER_BACK;
  m->controller(c, none, 1000);
  c.keys = 0;
  m->controller(c, none, 1100);
  CHECK(only(*m, RETRO_DEVICE_ID_JOYPAD_B));
  const nbt::controller::Event menu = {NBT_CONTROLLER_MENU, 0, 0};
  c.keys = NBT_CONTROLLER_MENU;
  m->controller(c, menu, 2000);
  CHECK(m->poll(2000) == nbt::frontend::kCommandMenu);
  delete m;
}

void test_keyboard() {
  PadMapper* m = new PadMapper(snes9x::controls());
  const Expect keys[] = {{'z', RETRO_DEVICE_ID_JOYPAD_B},
                         {'x', RETRO_DEVICE_ID_JOYPAD_A},
                         {'a', RETRO_DEVICE_ID_JOYPAD_Y},
                         {'s', RETRO_DEVICE_ID_JOYPAD_X},
                         {'q', RETRO_DEVICE_ID_JOYPAD_L},
                         {'w', RETRO_DEVICE_ID_JOYPAD_R},
                         {nbt::app::kHostKeyReturn, RETRO_DEVICE_ID_JOYPAD_START},
                         {nbt::app::kHostKeyRightShift, RETRO_DEVICE_ID_JOYPAD_SELECT},
                         {nbt::app::kHostKeyLeft, RETRO_DEVICE_ID_JOYPAD_LEFT}};
  for (size_t i = 0; i < sizeof(keys) / sizeof(keys[0]); ++i) {
    m->host_key(static_cast<int>(keys[i].control), true);
    CHECK(only(*m, keys[i].action));
    m->host_key(static_cast<int>(keys[i].control), false);
    CHECK(only(*m, -1));
  }
  m->host_key(nbt::app::kHostKeyEscape, true);
  CHECK(m->poll(0) == nbt::frontend::kCommandMenu);
  delete m;
}

}  // namespace

int main() {
  test_pads();
  test_controller();
  test_keyboard();
  printf("SNES CONTROLS: ALL TESTS PASSED\n");
  return 0;
}
