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

CC ?= gcc
CXX ?= g++

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
ASAN_FLAGS := -O1 -g -fsanitize=address -fno-omit-frame-pointer

.PHONY: all host test test-asan check-static-init format package package-args notice clean

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
	python3 tools/package_version.py --check release/package.args
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
	clang-format -i src/*.cpp src/*.hpp src/compat/*.h src/compat/*.c tests/*.cpp

# --- The head unit: a module, built without the QNX SDP, run by nbt-runner
# (sdk/module). The same core and application, compiled with the NBT toolchain
# against picolibc and libc++. The head unit stops a misaligned access with
# SIGBUS: the core reads memory byte by byte where port.h would make unaligned
# accesses (src/compat/snes9x_aligned.h). ---
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

$(OBJ_DIR)/mod/compat/%.o: src/compat/%.c $(call stamp,mod) | nbt-sdk-mod
	@mkdir -p $(dir $@)
	$(NBT_MOD_CC) $(MOD_CORE_CFLAGS) -MMD -MP -c $< -o $@

# Snes9x's NTSC filter (filter/snes_ntsc.c) is LGPL-2.1, and a module runs
# inside nbt-runner, which links QNX code: LGPL code only runs in a guest. The
# application never turns the filter on; src/compat/snes_ntsc_off.c stands in
# for it so libretro.cpp links. The desktop builds keep upstream's.
MOD_OBJ := $(filter-out %/filter/snes_ntsc.o,$(call core_objs,mod)) $(call app_objs,mod) \
	$(OBJ_DIR)/mod/compat/snes_ntsc_off.o

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

# release/package.args's Snes9x version (tools/package_version.py): again
# when the pin moves; `make test` fails until then.
package-args:
	python3 tools/package_version.py release/package.args

# --- The signed package (release/package.args describes it) ---
# The module: NBT Manager's nbt-runner runs it (bridge 1.7, runner).
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

# legal/NOTICE.txt (tools/make_notice.py): again when the pin, the SDK or the
# toolchain changes.
notice:
	NBT_SDK_DIR=$(NBT_SDK_ROOT) NBT_TOOLCHAIN=$(NBT_TOOLCHAIN) python3 tools/make_notice.py

clean:
	rm -rf $(BUILD_DIR)

DEPS := $(shell find $(OBJ_DIR) -name '*.d' 2>/dev/null)
-include $(DEPS)

$(call nbt_stamp,$(call stamp,host),$(CC) $(CXX) $(CORE_INC) $(CORE_DEFS) $(CORE_CXXFLAGS) | $(CORE_CFLAGS) \
	| $(APP_INC) $(APP_CXXFLAGS),$(CC) $(CXX))
$(call nbt_stamp,$(call stamp,asan),$(CC) $(CXX) $(CORE_INC) $(CORE_DEFS) $(CORE_CXXFLAGS) | $(CORE_CFLAGS) \
	| $(APP_INC) $(APP_CXXFLAGS) | $(ASAN_FLAGS) -fsanitize=undefined,$(CC) $(CXX))
$(call nbt_stamp,$(call stamp,mod),$(NBT_MOD_CC) $(MOD_CORE_CXXFLAGS) | $(MOD_CORE_CFLAGS) | $(MOD_APP_CXXFLAGS),, \
	$(NBT_TOOLCHAIN)/VERSION)
