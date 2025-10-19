# ============================================================
# Zelda: Shattered Realms — Makefile using libdragon n64.mk
# Mirrors libdragon examples; adds aliases to avoid missing-target errors.
# ============================================================

# Where libdragon installed its SDK (your workflow sets this)
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
TARGET          := shattered_realms          # base name (no extension)
N64_ROM_TITLE   := Shattered Realms          # emulator title
N64_ROM_REGION  := E
N64_ROM_MEDIA   := N
N64_ROM_SIZE    := 2M

# ---------- Sources ----------
SOURCES := \
  src/main.c \
  src/hud.c \
  src/dungeon.c \
  src/combat.c \
  src/audio.c

# Extra include dirs if needed:
# INCLUDES += -Isrc

# ---------- Assets / ROMFS ----------
ROMFS_DIRS := assets/romfs

# ---------- Invoke libdragon build macro ----------
# Produces:
#   build/$(TARGET).elf
#   build/$(TARGET).dfs  (if ROMFS_DIRS set)
#   build/$(TARGET).z64
$(call N64_BUILD_ROM,$(TARGET))

# ---------- Aliases / default goals ----------
.PHONY: default all copyouts showpaths clean distclean
.DEFAULT_GOAL := default
all: default

# Some previous rules (or old workflow lines) may ask for 'build/$(TARGET)' without extension.
# Provide a forwarding alias so the build cannot fail on that name anymore.
build/$(TARGET): build/$(TARGET).z64
	@true

# Build the real ROM, then copy to repo root and print header/size.
default: build/$(TARGET).z64 copyouts
	@echo "ROM header (first 16 bytes):"
	xxd -l 16 -g 1 $(TARGET).z64 || true
	@echo "ROM size (bytes):"
	@wc -c < $(TARGET).z64 || true

copyouts:
	# Copy to repo root for CI artifact upload
	cp -f build/$(TARGET).z64 $(TARGET).z64
	cp -f build/$(TARGET).elf $(TARGET).elf
	@if [ -f build/$(TARGET).dfs ]; then cp -f build/$(TARGET).dfs romfs.dfs; fi

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
