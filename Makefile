# ============================================================
# Zelda: Shattered Realms — explicit build with libdragon tools
# - Compiles & links explicitly
# - Verifies exactly one main()
# - Uses n64elfcompress (INPUT ELF first, OUTPUT BIN64 second)
# - Packs with n64tool -T and fixes CRC if available
# - Prints ROM magic (80371240) and size
# ============================================================

N64_INST    ?= /opt/libdragon
MIPS_PREFIX ?= mips64-elf

CC       := $(MIPS_PREFIX)-gcc
NM       := $(MIPS_PREFIX)-nm
OBJCOPY  := $(MIPS_PREFIX)-objcopy

N64ELFCOMPRESS := n64elfcompress
N64TOOL        := n64tool

TITLE   := Shattered Realms
ELF     := shattered_realms.elf
BIN64   := shattered_realms.bin64
ROM     := shattered_realms.z64
DFS     := romfs.dfs
ROMSIZE := 2M

SRC_DIR    := src
ASSETS_DIR := assets/romfs

# --- Minimal sources to prove boot; add others after this works ---
SOURCES := \
  $(SRC_DIR)/main.c

OBJS := $(SOURCES:.c=.o)

# --- Locate libdragon headers/libs/ldscript ---
DRAGON_INC     := $(firstword $(wildcard $(N64_INST)/mips64-elf/include) /n64_toolchain/mips64-elf/include)
DRAGON_LIBDIR  := $(firstword $(wildcard $(N64_INST)/mips64-elf/lib)     /n64_toolchain/mips64-elf/lib)
N64_LDSCRIPT   := $(firstword $(wildcard $(N64_INST)/mips64-elf/lib/n64.ld) /n64_toolchain/mips64-elf/lib/n64.ld)

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

# Fail fast if main.c missing or more than one int main(...) is present
precheck:
	@set -e; \
	echo "[INFO] Using headers at $(DRAGON_INC)"; \
	test -f $(SRC_DIR)/main.c || { echo "ERROR: $(SRC_DIR)/main.c missing"; exit 1; }; \
	COUNT=$$(grep -R --include='*.c' -n "^[[:space:]]*int[[:space:]]\\+main[[:space:]]*(" $(SRC_DIR) 2>/dev/null | wc -l); \
	if [ "$$COUNT" -eq 0 ]; then echo "ERROR: No int main(...) found under $(SRC_DIR)/"; exit 1; fi; \
	if [ "$$COUNT" -gt 1 ]; then echo "ERROR: More than one file defines main()"; grep -R --include='*.c' -n "^[[:space:]]*int[[:space:]]\\+main[[:space:]]*(" $(SRC_DIR) || true; exit 1; fi; \
	echo "OK: exactly one main(). Forcing rebuild…"

# Compile
$(SRC_DIR)/%.o: $(SRC_DIR)/%.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

# Link (ELF)
$(ELF): $(OBJS)
	@echo "  [LD]  $(ELF)"
	$(CC) -o $@ $(OBJS) $(LDFLAGS)

# Convert ELF -> BIN64 (IMPORTANT: tool expects INPUT first, OUTPUT second)
$(BIN64): $(ELF)
	@echo "  [ELF->BIN64] $(BIN64)"
	$(N64ELFCOMPRESS) $(ELF) $(BIN64)

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

# Pack ROM: BIN64 first, then DFS, with TOC; then fix CRC
$(ROM): $(BIN64) $(DFS)
	@echo "  [ROM] $(ROM)"
	$(N64TOOL) -l $(ROMSIZE) -t "$(TITLE)" -T -o "$(ROM)" "$(BIN64)" -a 4 $(DFS)
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
	@$(RM) -f $(OBJS) $(ELF) $(BIN64) $(DFS) $(ROM) $(ASSETS_DIR)/readme.txt

distclean: clean
	@echo "  [DISTCLEAN]"
