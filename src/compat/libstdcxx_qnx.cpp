// SPDX-License-Identifier: MPL-2.0
/* What the QNX 6.6 toolchain's libstdc++ headers call and the head unit's
 * older libstdc++ (6.0.13, GCC 4.4) lacks; QNX build only. `make qnx-check`
 * lists any other such symbol. Nothing throws here (-fno-exceptions): a
 * failure is reported and ends the process, as an uncaught throw would. */
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

namespace std {

/* GCC 4.9's vector::at() and string::at() report an index out of range. */
void __throw_out_of_range_fmt(const char* fmt, ...) __attribute__((noreturn));
void __throw_out_of_range_fmt(const char* fmt, ...) {
  char text[256];
  va_list ap;
  va_start(ap, fmt);
  vsnprintf(text, sizeof(text), fmt, ap);
  va_end(ap);
  fprintf(stderr, "[snes9x] FATAL out of range: %s\n", text);
  abort();
}

}  // namespace std
