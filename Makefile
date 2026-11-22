# SPDX-License-Identifier: MPL-2.0
SHELL := /bin/bash

BUILD_DIR ?= build
OBJ_DIR := $(BUILD_DIR)/obj

APP_VERSION ?= 1.63.0
APP_SEQ ?= 1
APP_KEY ?=
# Sibling NBTFoundry checkouts; override as needed. The SDK is built into
# $(BUILD_DIR)/sdk; the manager is only needed for packaging.
NBT_SDK_DIR ?= ../sdk
NBT_MGR_DIR ?= ../manager
# QNX toolchain: the environment script to source, and the folder holding
# the head unit's libscreen.so.
QNX_ENV ?=
QNX_SCREEN_LIBDIR ?=

CC ?= gcc
CXX ?= g++
QCC ?= qcc
QNX_STRIP ?= ntoarmv7-strip
QNX_READELF ?= ntoarmv7-readelf
QNX_NM ?= ntoarmv7-nm

NBT_SDK_BUILD_DIR := $(abspath $(BUILD_DIR))/sdk
include $(NBT_SDK_DIR)/nbt-sdk.mk
# Each kind of object rebuilds when its compile command changes (the SDK's
# nbt-stamp.mk; the stamps are written at the end of this file).
stamp = $(OBJ_DIR)/$(1).stamp
ifeq ($(value nbt_stamp),)
$(error $(NBT_SDK_ROOT) has no nbt-stamp.mk: update that SDK checkout)
endif

# --- Snes9x: upstream's libretro source list, unmodified (third_party/snes9x) ---
CORE_DIR := third_party/snes9x
include $(CORE_DIR)/libretro/Makefile.common
CORE_INC := $(INCFLAGS)
CORE_DEFS := -DRIGHTSHIFT_IS_SAR -D__LIBRETRO__ -DALLOW_CPU_OVERCLOCK -DHAVE_STDINT_H -DHAVE_STRINGS_H
CORE_CXXFLAGS := -std=c++11 -O2 -w -fno-exceptions -fno-rtti $(CXXFLAGS)
CORE_CFLAGS := -std=gnu99 -O2 -w $(CFLAGS)
core_objs = $(patsubst $(CORE_DIR)/%.cpp,$(OBJ_DIR)/$(1)/core/%.o,$(SOURCES_CXX)) \
	$(patsubst $(CORE_DIR)/%.c,$(OBJ_DIR)/$(1)/core/%.o,$(SOURCES_C))

# --- Ours: the application on the SDK's libretro host ---
APP_SRC := src/controls.cpp src/main.cpp
APP_INC := $(NBT_SDK_INC) $(NBT_SDK_LIBRETRO_INC) -Isrc
APP_CXXFLAGS := -std=c++11 -O2 -Wall -Wextra -Werror -fno-exceptions -fno-rtti $(CXXFLAGS)
app_objs = $(patsubst %.cpp,$(OBJ_DIR)/$(1)/%.o,$(APP_SRC))

HOST_APP := $(BUILD_DIR)/nbt-snes9x-host
ASAN_APP := $(BUILD_DIR)/nbt-snes9x-asan
QNX_APP := $(BUILD_DIR)/nbt-snes9x-qnx
ASAN_FLAGS := -O1 -g -fsanitize=address -fno-omit-frame-pointer

.PHONY: all host test test-asan check-static-init format qnx qnx-env qnx-check package clean

all: host test

# --- Host (Linux, X11) ---
$(OBJ_DIR)/host/core/%.o: $(CORE_DIR)/%.cpp $(call stamp,host)
	@mkdir -p $(dir $@)
	$(CXX) $(CORE_INC) $(CORE_DEFS) $(CORE_CXXFLAGS) -MMD -MP -c $< -o $@

$(OBJ_DIR)/host/core/%.o: $(CORE_DIR)/%.c $(call stamp,host)
	@mkdir -p $(dir $@)
	$(CC) $(CORE_INC) $(CORE_DEFS) $(CORE_CFLAGS) -MMD -MP -c $< -o $@

$(OBJ_DIR)/host/src/%.o: src/%.cpp $(call stamp,host)
	@mkdir -p $(dir $@)
	$(CXX) $(APP_INC) $(APP_CXXFLAGS) -MMD -MP -c $< -o $@

$(HOST_APP): $(call core_objs,host) $(call app_objs,host) $(NBT_SDK_FRONT_HOST_LIBS)
	$(CXX) $(call core_objs,host) $(call app_objs,host) $(NBT_SDK_FRONT_HOST_LIBS) $(LDFLAGS) \
		$(NBT_SDK_HOST_LDLIBS) -o $@

host: $(HOST_APP) $(BUILD_DIR)/controls-test

# --- Sanitizer build: the core and ours under AddressSanitizer, ours under
# UBSan too (upstream's shifts and casts are the core's own business) ---
$(OBJ_DIR)/asan/core/%.o: $(CORE_DIR)/%.cpp $(call stamp,asan)
	@mkdir -p $(dir $@)
	$(CXX) $(CORE_INC) $(CORE_DEFS) $(CORE_CXXFLAGS) $(ASAN_FLAGS) -MMD -MP -c $< -o $@

$(OBJ_DIR)/asan/core/%.o: $(CORE_DIR)/%.c $(call stamp,asan)
	@mkdir -p $(dir $@)
	$(CC) $(CORE_INC) $(CORE_DEFS) $(CORE_CFLAGS) $(ASAN_FLAGS) -MMD -MP -c $< -o $@

$(OBJ_DIR)/asan/src/%.o: src/%.cpp $(call stamp,asan)
	@mkdir -p $(dir $@)
	$(CXX) $(APP_INC) $(APP_CXXFLAGS) $(ASAN_FLAGS) -fsanitize=undefined -MMD -MP -c $< -o $@

$(ASAN_APP): $(call core_objs,asan) $(call app_objs,asan) $(NBT_SDK_FRONT_ASAN_LIBS)
	$(CXX) $(ASAN_FLAGS) -fsanitize=undefined $(call core_objs,asan) $(call app_objs,asan) \
		$(NBT_SDK_FRONT_ASAN_LIBS) $(LDFLAGS) $(NBT_SDK_HOST_LDLIBS) -o $@

# --- Tests ---
$(OBJ_DIR)/host/tests/%.o: tests/%.cpp $(call stamp,host)
	@mkdir -p $(dir $@)
	$(CXX) $(APP_INC) $(APP_CXXFLAGS) -MMD -MP -c $< -o $@

$(BUILD_DIR)/controls-test: $(OBJ_DIR)/host/tests/controls_test.o $(OBJ_DIR)/host/src/controls.o \
		$(NBT_SDK_FRONT_HOST_LIBS)
	$(CXX) $^ $(LDFLAGS) $(NBT_SDK_HOST_LDLIBS) -o $@

$(BUILD_DIR)/controls-asan: tests/controls_test.cpp src/controls.cpp src/controls.hpp \
		$(NBT_SDK_FRONT_ASAN_LIBS)
	$(CXX) $(APP_INC) $(APP_CXXFLAGS) $(ASAN_FLAGS) -fsanitize=undefined tests/controls_test.cpp \
		src/controls.cpp $(NBT_SDK_FRONT_ASAN_LIBS) $(LDFLAGS) $(NBT_SDK_HOST_LDLIBS) -o $@

test: host
	$(BUILD_DIR)/controls-test
	NBT_SNES9X_APP=$(abspath $(HOST_APP)) NBT_MGR_DIR=$(abspath $(NBT_MGR_DIR)) \
		python3 -m unittest discover -s tests -v

test-asan: $(ASAN_APP) $(BUILD_DIR)/controls-asan
	ASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 \
		$(BUILD_DIR)/controls-asan
	ASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 \
		NBT_SNES9X_APP=$(abspath $(ASAN_APP)) NBT_MGR_DIR=$(abspath $(NBT_MGR_DIR)) \
		python3 -m unittest discover -s tests -v -k Play

# Our objects only: the core's own static constructors are upstream's, run by
# the loader before main (README, Head unit).
check-static-init: $(call app_objs,host)
	@set -e; \
	for obj in $^; do \
		ctors="$$(readelf -S "$$obj" | awk '/\.init_array|\.ctors/ {print $$2}')"; \
		if test -n "$$ctors"; then \
			echo "ERROR: static constructor section in $$obj: $$ctors"; exit 1; \
		fi; \
	done; \
	echo "OK: no .init_array/.ctors in our objects"
	+@$(NBT_SDK_MAKE) check-static-init

format:
	clang-format -i src/*.cpp src/*.hpp src/compat/*.h src/compat/*.cpp tests/*.cpp

# --- QNX (head unit, ARMv7) ---
qnx-env:
	@test -n "$(QNX_ENV)" || { echo "QNX_ENV is not set: make QNX_ENV=/path/to/qnx-env.sh ..."; exit 1; }
	@test -r "$(QNX_ENV)" || { echo "QNX_ENV=$(QNX_ENV) is not readable"; exit 1; }

QNX_C_VARIANT := -Vgcc_ntoarmv7le
QNX_CPP_VARIANT := -Vgcc_ntoarmv7le_gpp
# qcc defines __EXCEPTIONS even with -fno-exceptions, which turns libstdc++'s
# __try/__catch into real ones; src/compat/snes9x_qnx.h fills the toolchain's
# gaps for the core. The head unit stops a misaligned 16-bit load with SIGBUS
# (dev122, Immediate16): the core reads memory byte by byte, as in the module
# build (src/compat/snes9x_aligned.h; this gcc defines no __ARM_FEATURE_UNALIGNED).
QNX_NO_EXCEPTIONS := -Wc,-fno-exceptions -Wc,-fno-rtti -Wp,-U__EXCEPTIONS
QNX_CORE_CXXFLAGS := $(QNX_CPP_VARIANT) -D_QNX_SOURCE -O2 -Wc,-std=c++11 $(QNX_NO_EXCEPTIONS) -w \
	-include src/compat/snes9x_qnx.h -include src/compat/snes9x_aligned.h $(CORE_INC) $(CORE_DEFS)
QNX_CORE_CFLAGS := $(QNX_C_VARIANT) -D_QNX_SOURCE -O2 -Wc,-std=gnu99 -w $(CORE_INC) $(CORE_DEFS)
QNX_APP_CXXFLAGS := $(QNX_CPP_VARIANT) -D_QNX_SOURCE -O2 -Wc,-std=c++11 $(QNX_NO_EXCEPTIONS) \
	-Wc,-Wall -Wc,-Wextra $(APP_INC)
QNX_DEPFLAGS = -Wp,-MMD,$(@:.o=.d) -Wp,-MP -Wp,-MT,$@

$(OBJ_DIR)/qnx/core/%.o: $(CORE_DIR)/%.cpp src/compat/snes9x_qnx.h src/compat/snes9x_aligned.h $(call stamp,qnx) | qnx-env
	@mkdir -p $(dir $@)
	. "$(QNX_ENV)" && $(QCC) $(QNX_CORE_CXXFLAGS) $(QNX_DEPFLAGS) -c $< -o $@

$(OBJ_DIR)/qnx/core/%.o: $(CORE_DIR)/%.c $(call stamp,qnx) | qnx-env
	@mkdir -p $(dir $@)
	. "$(QNX_ENV)" && $(QCC) $(QNX_CORE_CFLAGS) $(QNX_DEPFLAGS) -c $< -o $@

$(OBJ_DIR)/qnx/src/%.o: src/%.cpp $(call stamp,qnx) | qnx-env
	@mkdir -p $(dir $@)
	. "$(QNX_ENV)" && $(QCC) $(QNX_APP_CXXFLAGS) $(QNX_DEPFLAGS) -c $< -o $@

$(OBJ_DIR)/qnx/compat/%.o: src/compat/%.cpp $(call stamp,qnx) | qnx-env
	@mkdir -p $(dir $@)
	. "$(QNX_ENV)" && $(QCC) $(QNX_APP_CXXFLAGS) $(QNX_DEPFLAGS) -c $< -o $@

QNX_OBJ := $(call core_objs,qnx) $(call app_objs,qnx) $(OBJ_DIR)/qnx/compat/libstdcxx_qnx.o

$(QNX_APP)-unstripped: $(QNX_OBJ) $(NBT_SDK_FRONT_QNX_LIBS) | qnx-env
	@test -n "$(QNX_SCREEN_LIBDIR)" || { echo "QNX_SCREEN_LIBDIR is not set (directory with libscreen.so)"; exit 1; }
	. "$(QNX_ENV)" && $(QCC) $(QNX_CPP_VARIANT) -lang-c++ $(QNX_OBJ) \
		$(NBT_SDK_FRONT_QNX_LIBS) -L$(QNX_SCREEN_LIBDIR) $(NBT_SDK_QNX_LDFLAGS) $(NBT_SDK_QNX_LDLIBS) -o $@

$(QNX_APP): $(QNX_APP)-unstripped
	. "$(QNX_ENV)" && $(QNX_STRIP) -o $@ $<

qnx: $(QNX_APP)

# The head unit's C++ runtime predates GLIBCXX_3.4.14 (libstdc++ 6.0.13, which
# the toolchain also ships); nothing may throw.
QNX_OLD_RUNTIME ?= $$QNX_TARGET/armle-v7/lib/libstdc++.so.6.0.13

qnx-check: qnx
	. "$(QNX_ENV)" && python3 tools/check_qnx_imports.py $(QNX_NM) $(QNX_APP)-unstripped \
		"$(QNX_OLD_RUNTIME)" "$$QNX_TARGET/armle-v7/lib/libc.so.3" "$$QNX_TARGET/armle-v7/lib/libm.so.2"
	. "$(QNX_ENV)" && $(QNX_READELF) -h -d $(QNX_APP)
	. "$(QNX_ENV)" && set -e; \
		bad="$$($(QNX_NM) -u $(QNX_APP)-unstripped | grep -E 'GLIBCXX_3\.4\.(1[4-9]|[2-9][0-9])|CXXABI_1\.3\.([4-9]|[1-9][0-9])|__cxa_throw' || true)"; \
		if test -n "$$bad"; then echo "Disallowed QNX ABI symbols:"; echo "$$bad"; exit 1; fi; \
		$(QNX_NM) -D $(QNX_APP)-unstripped | grep -qw kdMain || { echo "kdMain is not exported"; exit 1; }; \
		echo "OK: QNX binary ELF/ABI symbols verified, kdMain exported"

# --- A module: built without the QNX SDP, run by nbt-runner (sdk/module) ---
# The same core and application, compiled with Clang against picolibc and
# libc++ (no QNX compat header: those gaps are the QNX 6.6 libstdc++'s). The
# core reads memory byte by byte where port.h would make unaligned accesses
# (src/compat/snes9x_aligned.h).
MOD_CORE_CXXFLAGS := $(NBT_MOD_CXXFLAGS) -O2 -std=c++11 -w -fno-exceptions -fno-rtti \
	-include src/compat/snes9x_aligned.h $(CORE_INC) $(CORE_DEFS)
MOD_CORE_CFLAGS := $(NBT_MOD_CFLAGS) -O2 -std=gnu99 -w $(CORE_INC) $(CORE_DEFS)
MOD_APP_CXXFLAGS := $(NBT_MOD_CXXFLAGS) -O2 -std=c++11 -Wall -Wextra -Werror -fno-exceptions -fno-rtti \
	$(APP_INC)
MOD_APP := $(BUILD_DIR)/nbt-snes9x.so
# Snes9x's own licence (non-commercial, not GPL) and this application's.
MOD_APP_LICENSE := LicenseRef-Snes9x AND MPL-2.0

$(OBJ_DIR)/mod/core/%.o: $(CORE_DIR)/%.cpp src/compat/snes9x_aligned.h $(call stamp,mod) | nbt-sdk-mod
	@mkdir -p $(dir $@)
	$(NBT_MOD_CXX) $(MOD_CORE_CXXFLAGS) -MMD -MP -c $< -o $@

$(OBJ_DIR)/mod/core/%.o: $(CORE_DIR)/%.c $(call stamp,mod) | nbt-sdk-mod
	@mkdir -p $(dir $@)
	$(NBT_MOD_CC) $(MOD_CORE_CFLAGS) -MMD -MP -c $< -o $@

$(OBJ_DIR)/mod/src/%.o: src/%.cpp $(call stamp,mod) | nbt-sdk-mod
	@mkdir -p $(dir $@)
	$(NBT_MOD_CXX) $(MOD_APP_CXXFLAGS) -MMD -MP -c $< -o $@

MOD_OBJ := $(call core_objs,mod) $(call app_objs,mod)

$(MOD_APP): $(MOD_OBJ) $(NBT_SDK_MOD_DEPS)
	$(call nbt_module_link,$@,$(MOD_OBJ),$(MOD_APP_LICENSE))

.PHONY: module
module: $(MOD_APP)

# The core as the module build compiles it (src/compat/snes9x_aligned.h), run
# by the tests on the desktop with the alignment sanitizer: the head unit
# stops a misaligned access with SIGBUS, which x86 never shows.
.PHONY: test-align
test-align:
	$(MAKE) BUILD_DIR=$(BUILD_DIR)/align test-asan CORE_DEFS="$(CORE_DEFS) \
		-include $(CURDIR)/src/compat/snes9x_aligned.h -fsanitize=alignment -fno-sanitize-recover=alignment"

# --- The signed package (release/package.args describes it) ---
# The module: NBT Manager's nbt-runner runs it (bridge 1.7, runner). The QNX
# build stays for comparisons on the car; it is not what packages carry.
PACKAGE_INPUT ?= $(MOD_APP)
PACKAGE := $(BUILD_DIR)/snes9x-$(APP_VERSION).nbt

package: $(PACKAGE_INPUT)
	@test -f "$(APP_KEY)" || { echo "APP_KEY must name the RSA signing key"; exit 1; }
	@test -f "$(NBT_MGR_DIR)/tools/package.py" || { echo "NBT_MGR_DIR=$(NBT_MGR_DIR) has no tools/package.py"; exit 1; }
	rm -f $(PACKAGE)
	python3 $(NBT_MGR_DIR)/tools/package.py @release/package.args \
		--version "$(APP_VERSION)" \
		--sequence "$(APP_SEQ)" \
		--key "$(APP_KEY)" \
		--output $(PACKAGE) \
		$(PACKAGE_INPUT)

clean:
	rm -rf $(BUILD_DIR)

DEPS := $(shell find $(OBJ_DIR) -name '*.d' 2>/dev/null)
-include $(DEPS)

$(call nbt_stamp,$(call stamp,host),$(CC) $(CXX) $(CORE_INC) $(CORE_DEFS) $(CORE_CXXFLAGS) | $(CORE_CFLAGS) \
	| $(APP_INC) $(APP_CXXFLAGS),$(CC) $(CXX))
$(call nbt_stamp,$(call stamp,asan),$(CC) $(CXX) $(CORE_INC) $(CORE_DEFS) $(CORE_CXXFLAGS) | $(CORE_CFLAGS) \
	| $(APP_INC) $(APP_CXXFLAGS) | $(ASAN_FLAGS) -fsanitize=undefined,$(CC) $(CXX))
$(call nbt_stamp,$(call stamp,qnx),$(if $(QNX_ENV),$(QNX_ENV) $(QCC) $(QNX_CORE_CXXFLAGS) | $(QNX_CORE_CFLAGS) \
	| $(QNX_APP_CXXFLAGS)))
$(call nbt_stamp,$(call stamp,mod),$(NBT_MOD_CC) $(MOD_CORE_CXXFLAGS) | $(MOD_CORE_CFLAGS) | $(MOD_APP_CXXFLAGS),, \
	$(NBT_TOOLCHAIN)/VERSION)
