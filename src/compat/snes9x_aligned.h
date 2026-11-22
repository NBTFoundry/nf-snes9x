/* SPDX-License-Identifier: MPL-2.0 */
/* Included first in every core file of the head unit's builds (the module
 * build, -mno-unaligned-access). Snes9x's port.h reads
 * and writes 16- and 32-bit values with plain loads and stores on every ARM
 * target (FAST_LSB_WORD_ACCESS), at the addresses the emulated CPU uses, odd
 * ones included; the head unit stops such a process with SIGBUS. Without
 * unaligned access, the core takes port.h's own byte-wise forms, as on a
 * target port.h does not list. port.h itself is included here once (its
 * guard keeps the core's own includes from redefining these). */
#ifndef NF_SNES9X_ALIGNED_H
#define NF_SNES9X_ALIGNED_H

#include "port.h"

#ifndef __ARM_FEATURE_UNALIGNED
#undef FAST_LSB_WORD_ACCESS
#undef READ_WORD
#undef READ_3WORD
#undef READ_DWORD
#undef WRITE_WORD
#undef WRITE_3WORD
#undef WRITE_DWORD
#define READ_WORD(s) (*(uint8*)(s) | (*((uint8*)(s) + 1) << 8))
#define READ_3WORD(s) (*(uint8*)(s) | (*((uint8*)(s) + 1) << 8) | (*((uint8*)(s) + 2) << 16))
#define READ_DWORD(s) \
  (*(uint8*)(s) | (*((uint8*)(s) + 1) << 8) | (*((uint8*)(s) + 2) << 16) | (*((uint8*)(s) + 3) << 24))
#define WRITE_WORD(s, d) *(uint8*)(s) = (uint8)(d), *((uint8*)(s) + 1) = (uint8)((d) >> 8)
#define WRITE_3WORD(s, d) \
  *(uint8*)(s) = (uint8)(d), *((uint8*)(s) + 1) = (uint8)((d) >> 8), *((uint8*)(s) + 2) = (uint8)((d) >> 16)
#define WRITE_DWORD(s, d)                                                                          \
  *(uint8*)(s) = (uint8)(d), *((uint8*)(s) + 1) = (uint8)((d) >> 8), *((uint8*)(s) + 2) = (uint8)((d) >> 16), \
  *((uint8*)(s) + 3) = (uint8)((d) >> 24)
#endif

#endif
