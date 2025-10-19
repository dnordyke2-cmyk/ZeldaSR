# ============================================================
# Zelda: Shattered Realms — Makefile using libdragon n64.mk
# This mirrors the libdragon examples' build system.
# It yields a bootable .z64 like the example that worked in Ares.
# ============================================================

# Where libdragon installed its SDK (the workflow exports this)
N64_INST ?= /opt/libdragon

# Include libdragon's canonical build machinery
include $(N64_INST)/n64.mk

# ---------- Project metadata ----------
# ROM file base name (without extension)
TARGET       := shattered_realms

# What shows up in emulator title
N64_ROM_TITLE  := Shattered Realms
# Region & media (match example defaults)
N64_ROM_REGION := E
N64_ROM_MEDIA  := N
# ROM size; libdragon expands/pads as needed
N64_ROM_SIZE   := 2M

# ---------- Sources ----------
# Add your C files here (relative paths OK)
SOURCES := \
  src/main.c \
  src/hud.c \
  src/dungeon.c \
  src/combat.c \
  src/audio.c

# (Optional) extra include dirs:
# INCLUDES += -Isrc

# ---------- Assets / ROMFS ----------
# Put files under assets/romfs/... ; they'll be packed into a DFS
ROMFS_DIRS := assets/romfs

# ---------- Build outputs ----------
# This macro from n64.mk produces:
#   build/$(TARGET).elf
#   build/$(TARGET).dfs     (if ROMFS_DIRS are set)
#   build/$(TARGET).z64
# It also handles TOC/packaging in the libdragon-approved way.
$(call N64_BUILD_ROM, $(TARGET))

# ---------- Convenience targets ----------
.PHONY: all clean distclean showpaths

all: build/$(TARGET).z64
	@# Copy outputs to repo root for CI artifact upload (optional)
	cp -f build/$(TARGET).z64 $(TARGET).z64
	cp -f build/$(TARGET).elf $(TARGET).elf
	@if [ -f build/$(TARGET).dfs ]; then cp -f build/$(TARGET).dfs romfs.dfs; fi
	@echo "ROM header (16 bytes):"
	xxd -l 16 -g 1 $(TARGET).z64 || true

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
