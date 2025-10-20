# ============================================================
# Zelda: Shattered Realms — build via libdragon n64.mk (example-parity)
# - Uses libdragon's full pipeline (incl. n64elfcompress)
# - Minimal sources (only main.c) to lock boot; add others after booting
# - Prints ROM header/size; fails fast if main() missing/duplicated
# ============================================================

# SDK install root (your workflow sets this after building libdragon)
N64_INST ?= /opt/libdragon

# ---------- Project metadata ----------
TARGET          := shattered_realms
N64_ROM_TITLE   := Shattered Realms
N64_ROM_REGION  := E
N64_ROM_MEDIA   := N
N64_ROM_SIZE    := 2M

# ---------- Sources (INTENTIONALLY MINIMAL; prove boot first) ----------
SOURCES := \
  src/main.c

# ---------- ROMFS ----------
ROMFS_DIRS := assets/romfs

# --- Find libdragon's n64.mk (common locations) ---
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
  Ensure your workflow copies /tmp/libdragon/n64.mk to $(N64_INST)/n64.mk)
endif

include $(N64_MK)

# This macro (from n64.mk) produces:
#   build/$(TARGET).elf  (processed via n64elfcompress)
#   build/$(TARGET).z64
#   build/$(TARGET).dfs (if ROMFS present)
$(call N64_BUILD_ROM,$(TARGET))

# ---------- Goals & helpers ----------
.PHONY: default all precheck copyouts showpaths clean distclean
.DEFAULT_GOAL := default
all: default

# Fail fast if main() is missing or duplicated
precheck:
	@set -e; \
	echo "[INFO] Using n64.mk at: $(N64_MK)"; \
	echo "[INFO] SOURCES=$(SOURCES)"; \
	test -f src/main.c || { echo "ERROR: src/main.c missing"; exit 1; }; \
	COUNT=$$(grep -R --include='*.c' -n "int[[:space:]]\\+main[[:space:]]*(" src | wc -l); \
	if [ "$$COUNT" -eq 0 ]; then echo "ERROR: No main() found under src/"; exit 1; fi; \
	if [ "$$COUNT" -gt 1 ]; then echo "ERROR: More than one file defines main()"; grep -R --include='*.c' -n "int[[:space:]]\\+main[[:space:]]*(" src || true; exit 1; fi; \
	echo "OK: exactly one main()."

# Build via n64.mk (runs the exact example pipeline), then copy & print info
default: precheck build/$(TARGET).z64 copyouts
	@echo "ROM header (first 16 bytes):"
	xxd -l 16 -g 1 $(TARGET).z64 || true
	@echo "ROM size (bytes):"
	@wc -c < $(TARGET).z64 || true

# Copy to repo root for artifact upload
copyouts:
	cp -f build/$(TARGET).z64 $(TARGET).z64
	cp -f build/$(TARGET).elf $(TARGET).elf
	@if [ -f build/$(TARGET).dfs ]; then cp -f build/$(TARGET).dfs romfs.dfs; fi

showpaths:
	@echo "Using N64_INST     = $(N64_INST)"
	@echo "n64.mk             = $(N64_MK)"
	@echo "N64_TOOLCHAIN_ROOT = $(N64_TOOLCHAIN_ROOT)"
	@echo "N64_TRIPLET        = $(N64_TRIPLET)"
	@echo "N64_CC             = $(N64_CC)"
	@echo "N64_LD_SCRIPT      = $(N64_LD_SCRIPT)"

clean:
	@$(RM) -rf build

distclean: clean
	@$(RM) -f $(TARGET).z64 $(TARGET).elf romfs.dfs
