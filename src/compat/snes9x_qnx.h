// SPDX-License-Identifier: MPL-2.0
/* Gaps of the QNX toolchains (6.5 SP1 gcc 4.8.3, 6.6 gcc 4.9.3) for upstream Snes9x,
 * included before each core source of the QNX build (-include), so that the
 * submodule stays unmodified.
 *
 * - QNX's <math.h> brings Dinkumware's type traits into std unless
 *   libstdc++'s <type_traits> came first; it then clashes with libstdc++.
 * - That <math.h> declares the C99 functions in std only: trunc is used
 *   unqualified.
 * - This libstdc++ has no std::to_string (no C99 vsnprintf in its
 *   configuration). */
#ifndef NBT_SNES9X_QNX_H
#define NBT_SNES9X_QNX_H

#ifdef __cplusplus
/* QNX 6.5's <math.h> declares the C99 functions (trunc) only with _HAS_C9X;
 * 6.6's sets it already. */
#ifndef _HAS_C9X
#define _HAS_C9X 1
#endif
#include <type_traits>

#include <math.h>
#include <stdio.h>

#include <string>

using std::trunc;

namespace std {

#define NBT_TO_STRING(type, format)              \
  inline string to_string(type value) {          \
    char text[24];                               \
    snprintf(text, sizeof(text), format, value); \
    return string(text);                         \
  }
NBT_TO_STRING(int, "%d")
NBT_TO_STRING(unsigned, "%u")
NBT_TO_STRING(long, "%ld")
NBT_TO_STRING(unsigned long, "%lu")
NBT_TO_STRING(long long, "%lld")
NBT_TO_STRING(unsigned long long, "%llu")
#undef NBT_TO_STRING

}  // namespace std
#endif /* __cplusplus */

#endif /* NBT_SNES9X_QNX_H */
