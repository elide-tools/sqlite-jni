# Copyright (c) 2024 Elide Technologies, Inc.
#
# Licensed under the MIT license (the "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#   https://opensource.org/license/mit/
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under the License.

#
# Makefile: SQLite3 + JNI (Elide)
#
# Builds libsqlite3elide.a (Unix) / sqlite3elide.lib (Windows) — a static SQLite3 library with
# Elide's JNI extensions baked into the amalgamation.
#
# Usage:
#   make install JAVA_HOME=/path/to/jdk [RELEASE=yes] [VERBOSE=no]
#   make clean
#
# Required:
#   JAVA_HOME - Path to a JDK installation (for jni.h / jni_md.h headers)
#
# Optional:
#   RELEASE     - yes/no (default: yes). Controls optimization level.
#   NATIVE      - yes/no (default: no). Use -march=native instead of generic tuning.
#   MUSL        - yes/no (default: no). Build for musl libc.
#   CROSS_HOST  - Cross-compilation host triple (e.g., aarch64-linux-gnu).
#   VERBOSE     - yes/no (default: no). Show commands.
#

VERBOSE ?= no
RELEASE ?= yes
NATIVE ?= no
MUSL ?= no

REPO_ROOT := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

# ---- Platform Detection ----

OS ?= $(shell uname -s)
ARCH ?= $(shell uname -m)
UNAME_P := $(shell uname -p)
JOBS ?= $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# ---- Verbosity ----

ifeq ($(VERBOSE),yes)
RULE ?=
else
RULE ?= @
endif

# ---- Tunables ----

MACOS_MIN_VERSION ?= 11.0
MODERN_X86_64_ARCH ?= x86-64-v3
MODERN_X86_64_TUNE ?= znver3
MODERN_ARM64_ARCH ?= armv8-a+crypto+crc+simd
MODERN_ARM64_TUNE ?= neoverse-n1

# ---- Base CFLAGS ----
# Derived from WHIPLASH tools/cflags/base, minus project-specific defines.

CFLAGS_BASE = -g -O3 -fPIC -fPIE
CFLAGS_BASE += -fstack-clash-protection -fstack-protector-strong
CFLAGS_BASE += -fexceptions -ffunction-sections -fdata-sections
CFLAGS_BASE += -fno-omit-frame-pointer -fno-strict-aliasing
CFLAGS_BASE += -fno-strict-overflow -fno-delete-null-pointer-checks

# Architecture-specific hardening
ifeq ($(ARCH),x86_64)
  CFLAGS_BASE += -fcf-protection=full
else ifneq (,$(filter arm% aarch64,$(UNAME_P) $(ARCH)))
  CFLAGS_BASE += -mbranch-protection=standard
endif

# Release vs debug optimization
ifeq ($(RELEASE),yes)
  CFLAGS_BASE += -O3 -ffat-lto-objects
else
  CFLAGS_BASE += -O1 -g -ffat-lto-objects
endif

# macOS minimum deployment target
ifeq ($(OS),Darwin)
  CFLAGS_BASE += -mmacosx-version-min=$(MACOS_MIN_VERSION)
endif

# Architecture tuning
ifeq ($(NATIVE),yes)
  ifeq ($(OS),Darwin)
    ifeq ($(UNAME_P),arm)
      CFLAGS_BASE += -march=$(MODERN_ARM64_ARCH) -mtune=$(MODERN_ARM64_TUNE) -D__ARM_NEON -D__ARM_FEATURE_AES -D__ARM_FEATURE_SHA2
    else
      CFLAGS_BASE += -march=native -mtune=native
    endif
  else
    CFLAGS_BASE += -march=native -mtune=native
  endif
else
  ifeq ($(ARCH),x86_64)
    CFLAGS_BASE += -march=$(MODERN_X86_64_ARCH) -mtune=$(MODERN_X86_64_TUNE)
  endif
endif

# Linker hardening (Linux only)
LDFLAGS_BASE =
ifneq ($(OS),Darwin)
  LDFLAGS_BASE += -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack -Wl,-z,separate-code
endif

# ---- Cross-compilation ----

ifdef CROSS_HOST
  TARGET_FLAGS += --host=$(CROSS_HOST)
  export CC := $(CROSS_HOST)-gcc
  export CXX := $(CROSS_HOST)-g++
endif

ifeq ($(MUSL),yes)
  TARGET_FLAGS += --host=$(ARCH)-linux-musl
  export CC := musl-gcc
  export LD := ld
endif

# ---- SQLite Configure Flags ----
# Identical to WHIPLASH third_party/Makefile.

SQLITE3_CONFIGURE  = --enable-all
SQLITE3_CONFIGURE += --disable-debug
SQLITE3_CONFIGURE += --enable-static
SQLITE3_CONFIGURE += --enable-shared
SQLITE3_CONFIGURE += --column-metadata
SQLITE3_CONFIGURE += --geopoly
SQLITE3_CONFIGURE += --memsys5
SQLITE3_CONFIGURE += --scanstatus
SQLITE3_CONFIGURE += --update-limit
SQLITE3_CONFIGURE += --with-tempstore=yes
SQLITE3_CONFIGURE += --amalgamation-extra-src=sqlite3jni.c
SQLITE3_CONFIGURE += --dll-basename=libsqlite3elide
SQLITE3_CONFIGURE += --disable-math
SQLITE3_CONFIGURE += --disable-tcl

# ---- SQLite -D Compile Flags ----
# Identical to WHIPLASH third_party/Makefile.

SQLITE3_FLAGS  = SQLITE_CORE=1
SQLITE3_FLAGS += SQLITE_DEFAULT_FILE_PERMISSIONS=0666
SQLITE3_FLAGS += SQLITE_DEFAULT_MEMSTATUS=0
SQLITE3_FLAGS += SQLITE_DISABLE_PAGECACHE_OVERFLOW_STATS=1
SQLITE3_FLAGS += SQLITE_ENABLE_API_ARMOR=1
SQLITE3_FLAGS += SQLITE_ENABLE_COLUMN_METADATA=1
SQLITE3_FLAGS += SQLITE_ENABLE_DBSTAT_VTAB=1
SQLITE3_FLAGS += SQLITE_ENABLE_FTS3=1
SQLITE3_FLAGS += SQLITE_ENABLE_FTS3_PARENTHESIS=1
SQLITE3_FLAGS += SQLITE_ENABLE_FTS5=1
SQLITE3_FLAGS += SQLITE_ENABLE_LOAD_EXTENSION=1
SQLITE3_FLAGS += SQLITE_ENABLE_MATH_FUNCTIONS=0
SQLITE3_FLAGS += SQLITE_ENABLE_RTREE=1
SQLITE3_FLAGS += SQLITE_ENABLE_STAT4=1
SQLITE3_FLAGS += SQLITE_HAVE_ISNAN=1
SQLITE3_FLAGS += SQLITE_MAX_ATTACHED=25
SQLITE3_FLAGS += SQLITE_MAX_COLUMN=32767
SQLITE3_FLAGS += SQLITE_MAX_FUNCTION_ARG=127
SQLITE3_FLAGS += SQLITE_MAX_LENGTH=2147483647
SQLITE3_FLAGS += SQLITE_MAX_MMAP_SIZE=1099511627776
SQLITE3_FLAGS += SQLITE_MAX_PAGE_COUNT=4294967294
SQLITE3_FLAGS += SQLITE_MAX_SQL_LENGTH=1073741824
SQLITE3_FLAGS += SQLITE_MAX_VARIABLE_NUMBER=250000
SQLITE3_FLAGS += SQLITE_THREADSAFE=1

# SQLite-specific CFLAGS: force -fPIC, suppress warnings, force -O3, add GVM_STATIC.
CFLAGS_SQLITE3 = $(CFLAGS_BASE) -fPIC -w -O3
SQLITE3_PREFIX = CC="$(CC)" CXX="$(CXX)" LD="ld" \
	CFLAGS="$(CFLAGS_SQLITE3) -DSQLITE_GVM_STATIC=1" \
	LDFLAGS="$(LDFLAGS_BASE)"

# ---- Directories ----

BUILD_DIR = $(REPO_ROOT)/sqlite
INSTALL_DIR = $(BUILD_DIR)/install
OUTPUT_DIR = $(REPO_ROOT)/out

# ---- Targets ----

.PHONY: all install clean distclean help settings

all: $(INSTALL_DIR)/lib/libsqlite3elide.a

# Configure SQLite with JNI headers
$(BUILD_DIR)/Makefile:
	@echo ""
	@echo "Configuring sqlite3..."
	$(RULE)cd $(BUILD_DIR) && \
		cp -f $(REPO_ROOT)/jni/sqlite3jni.c . && \
		cp -f $(REPO_ROOT)/jni/sqlite3jni.h . && \
		cp -fv $(JAVA_HOME)/include/jni.h . && \
		cp -fv $(JAVA_HOME)/include/*/jni_md.h . && \
		$(SQLITE3_PREFIX) ./configure \
			--prefix=$(INSTALL_DIR) \
			$(TARGET_FLAGS) \
			$(SQLITE3_CONFIGURE) \
			$(SQLITE3_FLAGS)

# Build the amalgamation and install
$(INSTALL_DIR)/lib/libsqlite3elide.a: $(BUILD_DIR)/Makefile
	@echo ""
	@echo "Building sqlite3..."
	$(RULE)cd $(BUILD_DIR) && \
		$(SQLITE3_PREFIX) $(MAKE) -j$(JOBS) sqlite3.c install
	$(RULE)cd $(INSTALL_DIR)/lib && \
		echo "Renaming libsqlite3.a -> libsqlite3elide.a..." && \
		mv libsqlite3.a libsqlite3elide.a
	@echo "SQLite3 ready."

# Copy build outputs to out/ for CI packaging
install: $(INSTALL_DIR)/lib/libsqlite3elide.a
	@echo "Creating output directory..."
	$(RULE)mkdir -p $(OUTPUT_DIR)/lib $(OUTPUT_DIR)/include
	$(RULE)cp -f $(INSTALL_DIR)/lib/libsqlite3elide.a $(OUTPUT_DIR)/lib/
	$(RULE)cp -f $(INSTALL_DIR)/include/sqlite3.h $(OUTPUT_DIR)/include/
	$(RULE)cp -f $(INSTALL_DIR)/include/sqlite3ext.h $(OUTPUT_DIR)/include/
	$(RULE)cp -f $(REPO_ROOT)/jni/sqlite3jni.h $(OUTPUT_DIR)/include/
	@echo "Installed to $(OUTPUT_DIR)"

clean:
	$(RULE)-cd $(BUILD_DIR) && $(MAKE) clean 2>/dev/null; true
	$(RULE)-rm -f $(BUILD_DIR)/Makefile $(BUILD_DIR)/sqlite3.c
	$(RULE)-rm -f $(BUILD_DIR)/sqlite3jni.c $(BUILD_DIR)/sqlite3jni.h
	$(RULE)-rm -f $(BUILD_DIR)/jni.h $(BUILD_DIR)/jni_md.h
	$(RULE)-rm -rf $(INSTALL_DIR) $(OUTPUT_DIR)

distclean: clean
	$(RULE)-cd $(BUILD_DIR) && git clean -xdf 2>/dev/null; true

settings:
	@echo "OS:       $(OS)"
	@echo "ARCH:     $(ARCH)"
	@echo "RELEASE:  $(RELEASE)"
	@echo "MUSL:     $(MUSL)"
	@echo "NATIVE:   $(NATIVE)"
	@echo "CFLAGS:   $(CFLAGS_SQLITE3) -DSQLITE_GVM_STATIC=1"
	@echo "LDFLAGS:  $(LDFLAGS_BASE)"

help:
	@echo "SQLite3 + JNI build system (Elide)"
	@echo ""
	@echo "Usage:"
	@echo "  make install JAVA_HOME=/path/to/jdk   Build and package to out/"
	@echo "  make clean                             Remove build artifacts"
	@echo "  make distclean                         Full clean (git clean sqlite/)"
	@echo "  make settings                          Print effective build settings"
	@echo ""
	@echo "Options:"
	@echo "  RELEASE=yes|no     Optimization level (default: yes)"
	@echo "  NATIVE=yes|no      Use -march=native (default: no)"
	@echo "  MUSL=yes|no        Target musl libc (default: no)"
	@echo "  CROSS_HOST=triple  Cross-compile host (e.g., aarch64-linux-gnu)"
	@echo "  VERBOSE=yes|no     Show commands (default: no)"
