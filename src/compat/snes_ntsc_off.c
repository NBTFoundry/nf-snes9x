// SPDX-License-Identifier: MPL-2.0
/* The module leaves out Snes9x's NTSC filter (filter/snes_ntsc.c, LGPL-2.1):
 * a module runs inside nbt-runner, which links the car's own libraries, and
 * LGPL code may only run in a guest. The application never turns the filter
 * on (its Filter setting is the GL filter; the core's snes9x_blargg stays
 * "disabled"), so these stand-ins only let libretro.cpp link: the filter does
 * nothing. */
#include "filter/snes_ntsc.h"

snes_ntsc_setup_t const snes_ntsc_monochrome = {0};
snes_ntsc_setup_t const snes_ntsc_composite = {0};
snes_ntsc_setup_t const snes_ntsc_svideo = {0};
snes_ntsc_setup_t const snes_ntsc_rgb = {0};

void snes_ntsc_init(snes_ntsc_t* ntsc, snes_ntsc_setup_t const* setup) {
  (void)ntsc;
  (void)setup;
}

void snes_ntsc_blit(snes_ntsc_t const* ntsc, SNES_NTSC_IN_T const* input, long in_row_width,
                    int burst_phase, int in_width, int in_height, void* rgb_out, long out_pitch) {
  (void)ntsc;
  (void)input;
  (void)in_row_width;
  (void)burst_phase;
  (void)in_width;
  (void)in_height;
  (void)rgb_out;
  (void)out_pitch;
}

void snes_ntsc_blit_hires(snes_ntsc_t const* ntsc, SNES_NTSC_IN_T const* input, long in_row_width,
                          int burst_phase, int in_width, int in_height, void* rgb_out,
                          long out_pitch) {
  (void)ntsc;
  (void)input;
  (void)in_row_width;
  (void)burst_phase;
  (void)in_width;
  (void)in_height;
  (void)rgb_out;
  (void)out_pitch;
}
