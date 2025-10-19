# ============================================================
# Zelda: Shattered Realms — Makefile using libdragon n64.mk
# Mirrors how libdragon examples build, to guarantee a bootable ROM.
# ============================================================

# Where libdragon installed its SDK (workflow sets this)
N64_INST ?= /opt/libdragon

# --- Locate libdragon's n64.mk (try multiple common locations) ---
N64_MK := $(firstword \
  $(wildcard $(N64_INST)/n64.mk) \
  $(wildcard $(N64_INST)/libdragon/n64.mk) \
  $(wildcard $(N64_INST)/mips64-elf/libdragon/n64.mk) \
)

ifeq ($(strip $(N64_MK)),)
$(error Could not find libdragon n64.mk. Looked in: \
  $(N64_INST)/n64.mk, \
  $(N64_INST)/libdragon/n64.mk, \
  $(N64_INST)/mips64-elf/libdragon/n64.mk. \
  Ensure the workflow copies /tmp/libdragon/n64.mk to $(N64_INST)/n64.mk)
endif

include $(N64_MK)

# ---------- Project metadata ----------
TARGET          := shattered_realms       # base name (no extension)
N64_ROM_TITLE   := Shattered Realms       # title shown by emulators
N64_ROM_REGION  := E                      # default: E (North America)
N64_ROM_MEDIA   := N                      # default: N (N64 Game Pak)
N64_ROM_SIZE    := 2M                     # desired ROM size

# ---------- Sources ----------
SOURCES := \
  src/main.c \
  src/hud.c \
  src/dungeon.c \
  src/combat.c \
  src/audio.c

# Add extra includes if needed:
# INCLUDES += -Isrc

# ---------- Assets / ROMFS ----------
ROMFS_DIRS := assets/romfs

# ---------- Build outputs ----------
# This macro (from n64.mk) builds:
#   build/$(TARGET).elf
#   build/$(TARGET).dfs (if ROMFS_DIRS set)
#   build/$(TARGET).z64
# and handles the correct pack/TOC/boot flow that libdragon expects.
$(call N64_BUILD_ROM,$(TARGET))

# ---------- Convenience copy & diagnostics ----------
.PHONY: all clean distclean showpaths

all: build/$(TARGET).z64
	# Copy to repo root for artifact upload
	cp -f build/$(TARGET).z64 $(TARGET).z64
	cp -f build/$(TARGET).elf $(TARGET).elf
	@if [ -f build/$(TARGET).dfs ]; then cp -f build/$(TARGET).dfs romfs.dfs; fi
	@echo "ROM header (first 16 bytes):"
	xxd -l 16 -g 1 $(TARGET).z64 || true
	@echo "ROM size (bytes):"
	@wc -c < $(TARGET).z64 || true

showpaths:
	@echo "Using N64_INST     = $(N64_INST)"
	@echo "n64.mk             = $(N64_MK)"
	@echo "N64_TOOLCHAIN_ROOT = $(N64_TOOLCHAIN_ROOT)"
	@echo "N64_CC             = $(N64_CC)"
	@echo "N64_LD_SCRIPT      = $(N64_LD_SCRIPT)"

clean:
	@$(RM) -rf build

distclean: clean
	@$(RM) -f $(TARGET).z64 $(TARGET).elf romfs.dfs
