# -------------------------------------------------------------
# Zelda: Shattered Realms — Minimal Alpha Build (libdragon 3.x)
# Target: Official libdragon .deb layout under /opt/libdragon
# -------------------------------------------------------------

# Toolchain
N64_PREFIX := mips64-elf-
CC         := $(N64_PREFIX)gcc

# Environment paths (installed by CI to /opt/libdragon)
N64_INST     ?= /opt/libdragon
LIBDRAGON    := $(N64_INST)

# Include/Lib paths for the .deb layout
INCLUDES     := -I$(LIBDRAGON)/mips64-elf/include
LIBDIR_LD    := $(LIBDRAGON)/mips64-elf/lib

# Auto-detect the ROM header among common locations
HEADER_CANDIDATES := $(LIBDRAGON)/lib/header $(LIBDRAGON)/mips64-elf/lib/header $(LIBDRAGON)/share/libdragon/header
HEADER            := $(firstword $(wildcard $(HEADER_CANDIDATES)))

# ---- Link order matters ----
LIBS       := -L$(LIBDIR_LD) -ldragon -lc -lm -ldragonsys

# Project sources
SRCS       := src/main.c src/hud.c src/dungeon.c src/combat.c src/audio.c
OBJS       := $(SRCS:.c=.o)

# Outputs
TARGET_ELF := shattered_realms.elf
TARGET_ROM := shattered_realms.z64
ROMFS      := assets/romfs

# Flags
CFLAGS  := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections $(INCLUDES)
LDFLAGS := -T $(LIBDIR_LD)/n64.ld $(LIBS) -Wl,--gc-sections

# Default
all: $(TARGET_ROM)

$(TARGET_ELF): $(OBJS)
	@echo "  [LD]  $@"
	$(CC) -o $@ $(OBJS) $(LDFLAGS)

$(TARGET_ROM): $(TARGET_ELF)
	@echo "  [ROM] $@"
	# Ensure ROMFS exists and is not empty (mkdfs fails on empty)
	@mkdir -p $(ROMFS)
	@if ! find $(ROMFS) -type f -not -name '.*' -mindepth 1 -print -quit | grep -q . ; then \
		echo "ROMFS is empty; creating placeholder readme.txt"; \
		echo "Shattered Realms ROMFS placeholder" > $(ROMFS)/readme.txt; \
	fi
	# mkdfs syntax: mkdfs <output.dfs> <input_dir>
	mkdfs romfs.dfs $(ROMFS)
	# Pick header path dynamically and validate
	@if [ -z "$(HEADER)" ]; then \
		echo "ERROR: Could not find N64 header at any of: $(HEADER_CANDIDATES)"; \
		exit 1; \
	fi
	@HEADER_SIZE=$$(wc -c < "$(HEADER)"); \
	if [ $$HEADER_SIZE -lt 4096 ]; then \
		echo "ERROR: Header file '$(HEADER)' is too small ($$HEADER_SIZE bytes). Needs >= 4096."; \
		exit 1; \
	fi
	# IMPORTANT: First file (ELF) cannot have an offset; add DFS afterward.
	# Optional: align the DFS to 4 bytes for cleanliness.
	n64tool -l 2M -t "Shattered Realms" -h "$(HEADER)" -o "$@" "$<" -a 4 romfs.dfs
	chksum64 "$@"

%.o: %.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	@echo "  [CLEAN]"
	rm -f $(OBJS) $(TARGET_ELF) $(TARGET_ROM) romfs.dfs

.PHONY: all clean
