# ============================================================
# Zelda: Shattered Realms — libdragon n64.mk with forced cross toolchain
# Ensures mips64-elf-* are used (never host g++) and verifies main() exists.
# ============================================================

# SDK root (CI places libdragon + toolchain here)
N64_INST ?= /opt/libdragon

# *** CRITICAL: force the cross triplet and tool vars BEFORE including n64.mk ***
N64_TRIPLET           ?= mips64-elf
export PATH           := $(N64_INST)/bin:$(PATH)

# Tell n64.mk exactly which tools to use
CC                    := $(N64_TRIPLET)-gcc
CXX                   := $(N64_TRIPLET)-g++
AR                    := $(N64_TRIPLET)-ar
AS                    := $(N64_TRIPLET)-as
LD                    := $(N64_TRIPLET)-ld
NM                    := $(N64_TRIPLET)-nm
RANLIB                := $(N64_TRIPLET)-ranlib
OBJCOPY               := $(N64_TRIPLET)-objcopy
OBJDUMP               := $(N64_TRIPLET)-objdump
STRIP                 := $(N64_TRIPLET)-strip

# Some libdragon n64.mk variants read N64_* as well
N64_CC                := $(CC)
N64_CXX               := $(CXX)
N64_AR                := $(AR)
N64_AS                := $(AS)
N64_LD                := $(LD)
N64_NM                := $(NM)
N64_RANLIB            := $(RANLIB)
N64_OBJCOPY           := $(OBJCOPY)
N64_OBJDUMP           := $(OBJDUMP)
N64_STRIP             := $(STRIP)

# ---------- Project metadata ----------
TARGET          := shattered_realms
N64_ROM_TITLE   := Shattered Realms
N64_ROM_REGION  := E
N64_ROM_MEDIA   := N
N64_ROM_SIZE    := 2M

# ---------- Sources (start minimal to PROVE boot) ----------
SOURCES := \
  src/main.c

# ---------- ROMFS (optional) ----------
ROMFS_DIRS := assets/romfs

# --- Find libdragon's n64.mk (installed by your workflow) ---
N64_MK := $(firstword \
  $(wildcard $(N64_INST)/n64.mk) \
  $(wildcard $(N64_INST)/libdragon/n64.mk) \
  $(wildcard $(N64_INST)/mips64-elf/libdragon/n64.mk))
ifeq ($(strip $(N64_MK)),)
$(error Could not find libdragon n64.mk. Ensure your CI copies /tmp/libdragon/n64.mk to $(N64_INST)/n64.mk)
endif

include $(N64_MK)

# This macro builds:
#   build/$(TARGET).elf
#   build/$(TARGET).z64
#   build/$(TARGET).dfs (if ROMFS present)
$(call N64_BUILD_ROM,$(TARGET))

# ---------- Goals & helpers ----------
.PHONY: default all precheck veryclean checktools checkmain copyouts showpaths clean distclean
.DEFAULT_GOAL := default
all: default

# Quick environment/probing and main() check
precheck:
	@set -e; \
	echo "[INFO] Using n64.mk at: $(N64_MK)"; \
	echo "[INFO] N64_TRIPLET=$(N64_TRIPLET)"; \
	echo "[INFO] PATH=$(PATH)"; \
	echo "[INFO] CC=$(CC)"; echo "[INFO] CXX=$(CXX)"; \
	command -v $(CC)  || { echo "ERROR: $(CC) not in PATH";  exit 1; }; \
	command -v $(CXX) || { echo "ERROR: $(CXX) not in PATH"; exit 1; }; \
	test -f src/main.c || { echo "ERROR: src/main.c missing"; exit 1; }; \
	COUNT=$$(grep -R --include='*.c' -n "^[[:space:]]*int[[:space:]]\\+main[[:space:]]*(" src 2>/dev/null | wc -l); \
	if [ "$$COUNT" -eq 0 ]; then echo "ERROR: No int main(...) found under src/"; exit 1; fi; \
	if [ "$$COUNT" -gt 1 ]; then echo "ERROR: More than one file defines main()"; grep -R --include='*.c' -n "^[[:space:]]*int[[:space:]]\\+main[[:space:]]*(" src || true; exit 1; fi; \
	echo "OK: exactly one main()."

# Hard clean to force recompilation with cross tools
veryclean:
	@echo "[CLEAN] removing build/ and root artifacts"
	@rm -rf build
	@rm -f $(TARGET).z64 $(TARGET).elf romfs.dfs

# Build ELF first, then verify ' T main' using the cross nm
build-elf: precheck veryclean
	@echo "[STEP] Building ELF only (to verify main symbol)…"
	@$(MAKE) -f $(lastword $(MAKEFILE_LIST)) build/$(TARGET).elf V=1 \
		N64_TRIPLET=$(N64_TRIPLET) CC=$(CC) CXX=$(CXX)

checkmain: build-elf
	@echo "[CHECK] Searching for ' T main' in objects with $(NM)…"
	@set -e; \
	OBJS=$$(echo build/*.o 2>/dev/null || true); \
	if [ -z "$$OBJS" ]; then echo "ERROR: no objects in build/"; exit 1; fi; \
	if ! $(NM) $$OBJS | grep -q ' T main$$'; then \
	  echo "ERROR: No 'main' symbol found in built objects. Compilation skipped main.c?"; \
	  $(NM) $$OBJS | grep -n main || true; \
	  exit 1; \
	fi; \
	echo "OK: main() symbol present."

# After ELF + symbol check, build ROM and copy/print info
default: checkmain
	@echo "[STEP] Building Z64…"
	@$(MAKE) -f $(lastword $(MAKEFILE_LIST)) build/$(TARGET).z64 V=1 \
		N64_TRIPLET=$(N64_TRIPLET) CC=$(CC) CXX=$(CXX)
	@$(MAKE) -f $(lastword $(MAKEFILE_LIST)) copyouts
	@echo "ROM header (first 16 bytes):"; xxd -l 16 -g 1 $(TARGET).z64 || true
	@echo "ROM size (bytes):"; wc -c < $(TARGET).z64 || true

# Copy to repo root for artifact upload
copyouts:
	cp -f build/$(TARGET).z64 $(TARGET).z64
	cp -f build/$(TARGET).elf $(TARGET).elf
	@if [ -f build/$(TARGET).dfs ]; then cp -f build/$(TARGET).dfs romfs.dfs; fi

showpaths:
	@echo "Using N64_INST     = $(N64_INST)"
	@echo "n64.mk             = $(N64_MK)"
	@echo "N64_TRIPLET        = $(N64_TRIPLET)"
	@echo "CC                 = $(CC)"
	@echo "CXX                = $(CXX)"
	@echo "N64_CC             = $(N64_CC)"
	@echo "N64_CXX            = $(N64_CXX)"

# Soft clean
clean:
	@rm -rf build

distclean: veryclean
