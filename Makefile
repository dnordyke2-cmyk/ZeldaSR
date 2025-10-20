# ============================================================
# Zelda: Shattered Realms — explicit build (compile/link/pack)
# - Exactly ONE main() (in src/main.c)
# - Non-deprecated display_get()
# - Clean build each run
# - Pack ELF+DFS with TOC (-T), fix CRC if available
# - Print ROM header/size
# ============================================================

N64_INST    ?= /opt/libdragon
MIPS_PREFIX ?= mips64-elf
CC          := $(MIPS_PREFIX)-gcc
NM          := $(MIPS_PREFIX)-nm

TITLE   := Shattered Realms
ELF     := shattered_realms.elf
ROM     := shattered_realms.z64
DFS     := romfs.dfs
ROMSIZE := 2M

SRC_DIR    := src
ASSETS_DIR := assets/romfs

# ---- Explicit sources (ensure only one main() in the set) ----
SOURCES := \
  $(SRC_DIR)/main.c \
  $(SRC_DIR)/entrypoint.c \
  $(SRC_DIR)/hud.c \
  $(SRC_DIR)/dungeon.c \
  $(SRC_DIR)/combat.c \
  $(SRC_DIR)/audio.c

OBJS := $(SOURCES:.c=.o)

# --- Locate libdragon headers, libs, and linker script ---
DRAGON_INC := $(firstword $(wildcard $(N64_INST)/mips64-elf/include) /n64_toolchain/mips64-elf/include)
DRAGON_LIBDIR := $(firstword $(wildcard $(N64_INST)/mips64-elf/lib) /n64_toolchain/mips64-elf/lib)
N64_LDSCRIPT := $(firstword $(wildcard $(N64_INST)/mips64-elf/lib/n64.ld) /n64_toolchain/mips64-elf/lib/n64.ld)

ifeq ($(strip $(DRAGON_INC)),)
$(error Could not find libdragon headers. Looked in $(N64_INST)/mips64-elf/include and /n64_toolchain/mips64-elf/include)
endif
ifeq ($(strip $(DRAGON_LIBDIR)),)
$(error Could not find libdragon libraries. Looked in $(N64_INST)/mips64-elf/lib and /n64_toolchain/mips64-elf/lib)
endif
ifeq ($(strip $(N64_LDSCRIPT)),)
$(error Could not find n64.ld. Looked in $(N64_INST)/mips64-elf/lib and /n64_toolchain/mips64-elf/lib)
endif

CFLAGS  := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections -I$(DRAGON_INC)
LDFLAGS := -T $(N64_LDSCRIPT) -L$(DRAGON_LIBDIR) -ldragon -lc -lm -ldragonsys -Wl,--gc-sections

.PHONY: all default clean distclean showpaths precheck fixcrc verifyrom

all: default
default: clean precheck $(ROM) verifyrom

showpaths:
	@echo "INC=$(DRAGON_INC)"
	@echo "LIBDIR=$(DRAGON_LIBDIR)"
	@echo "LDSCRIPT=$(N64_LDSCRIPT)"
	@echo "CC=$(CC)"
	@echo "SOURCES=$(SOURCES)"

# Fail fast if multiple mains exist or main() missing
precheck:
	@set -e; \
	test -f $(SRC_DIR)/main.c || { echo "ERROR: $(SRC_DIR)/main.c missing"; exit 1; }; \
	COUNT=$$(grep -R --include='*.c' -n "int[[:space:]]\\+main[[:space:]]*(" $(SRC_DIR) | wc -l); \
	if [ "$$COUNT" -eq 0 ]; then echo "ERROR: No main() found in src/"; exit 1; fi; \
	if [ "$$COUNT" -gt 1 ]; then echo "ERROR: More than one file defines main() in src/"; grep -R --include='*.c' -n "int[[:space:]]\\+main[[:space:]]*(" $(SRC_DIR) || true; exit 1; fi; \
	echo "OK: exactly one main() in src/main.c"

# Compile
$(SRC_DIR)/%.o: $(SRC_DIR)/%.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

# Link
$(ELF): $(OBJS)
	@echo "  [LD]  $(ELF)"
	$(CC) -o $@ $(OBJS) $(LDFLAGS)

# DFS (safe even if empty)
$(DFS): | $(ASSETS_DIR)
	@if [ -z "$$(find $(ASSETS_DIR) -type f -not -name '.keep' -print -quit)" ]; then \
		echo "ROMFS is empty; creating placeholder readme.txt"; \
		printf "ROMFS placeholder.\n" > $(ASSETS_DIR)/readme.txt; \
	fi
	@echo "  [DFS] $(DFS)"
	mkdfs $(DFS) $(ASSETS_DIR)

$(ASSETS_DIR):
	@mkdir -p $(ASSETS_DIR)
	@touch $(ASSETS_DIR)/.keep

# Pack ROM: ELF first, DFS second (aligned), WITH TOC
$(ROM): $(ELF) $(DFS)
	@echo "  [ROM] $(ROM)"
	n64tool -l $(ROMSIZE) -t "$(TITLE)" -T -o "$(ROM)" "$(ELF)" -a 4 $(DFS)
	@if [ ! -s "$(ROM)" ]; then echo "ERROR: n64tool did not create $(ROM)"; exit 1; fi
	@$(MAKE) -s fixcrc

# CRC fix (best-effort)
fixcrc:
	@set -e; \
	if command -v chksum64 >/dev/null 2>&1; then \
		echo "  [CRC] chksum64"; chksum64 "$(ROM)" >/dev/null; \
	elif command -v rn64crc >/dev/null 2>&1; then \
		echo "  [CRC] rn64crc -u"; rn64crc -u "$(ROM)"; \
	elif command -v n64crc >/dev/null 2>&1; then \
		echo "  [CRC] n64crc"; n64crc "$(ROM)"; \
	else \
		echo "[WARN] No checksum tool found; skipping CRC fix."; \
	fi

# Sanity check ROM magic + print size
verifyrom:
	@printf "  [MAGIC] "; xxd -l 4 -g 1 "$(ROM)" | awk 'NR==1{print $$2, $$3, $$4, $$5}'
	@HEAD=$$(xxd -l 4 -p "$(ROM)"); \
	if [ "$$HEAD" != "80371240" ]; then \
		echo "ERROR: ROM magic $$HEAD != 80371240 (.z64 big-endian)"; exit 1; \
	fi
	@echo "  [SIZE] $$(wc -c < "$(ROM)") bytes"
	@ls -lh "$(ROM)"

clean:
	@echo "  [CLEAN]"
	@$(RM) -f $(OBJS) $(ELF) $(DFS) $(ROM) $(ASSETS_DIR)/readme.txt

distclean: clean
	@echo "  [DISTCLEAN]"
