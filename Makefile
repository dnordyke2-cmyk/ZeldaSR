# ============================================================
# Zelda: Shattered Realms — explicit build (no n64.mk)
# Compile -> Link -> (ELF->ROM via n64tool OR ELF->BIN64->ROM) -> CRC -> Verify
# Handles the "single-argument" n64elfcompress variant automatically.
# ============================================================

N64_INST    ?= /opt/libdragon
MIPS_PREFIX ?= mips64-elf

CC      := $(MIPS_PREFIX)-gcc
CXX     := $(MIPS_PREFIX)-g++
NM      := $(MIPS_PREFIX)-nm

N64ELFCOMPRESS ?= n64elfcompress
N64TOOL        ?= n64tool

TITLE   := Shattered Realms
ELF     := shattered_realms.elf
BIN64   := shattered_realms.bin64
ROM     := shattered_realms.z64
DFS     := romfs.dfs
ROMSIZE := 2M

SRC_DIR    := src
ASSETS_DIR := assets/romfs

# ---- minimal sources to PROVE boot first ----
SOURCES := $(SRC_DIR)/main.c
OBJS    := $(SOURCES:.c=.o)

# ---- locate headers/libs/linker script ----
DRAGON_INC    := $(firstword $(wildcard $(N64_INST)/mips64-elf/include) /n64_toolchain/mips64-elf/include)
DRAGON_LIBDIR := $(firstword $(wildcard $(N64_INST)/mips64-elf/lib)     /n64_toolchain/mips64-elf/lib)
N64_LDSCRIPT  := $(firstword $(wildcard $(N64_INST)/mips64-elf/lib/n64.ld) /n64_toolchain/mips64-elf/lib/n64.ld)

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

.PHONY: all default clean distclean precheck showpaths fixcrc verifyrom

all: default
default: clean precheck $(ROM) verifyrom

# ---- diagnostics for CI ----
showpaths:
	@echo "TOOLCHAIN:"
	@echo "  CC  = $$(command -v $(CC)  || echo 'MISSING')"
	@echo "  CXX = $$(command -v $(CXX) || echo 'MISSING')"
	@echo "  NM  = $$(command -v $(NM)  || echo 'MISSING')"
	@echo "TOOLS:"
	@echo "  n64elfcompress = $$(command -v $(N64ELFCOMPRESS) || echo 'MISSING')"
	@echo "  n64elf2rom     = $$(command -v n64elf2rom || echo 'MISSING')"
	@echo "  n64tool        = $$(command -v $(N64TOOL) || echo 'MISSING')"
	@echo "LIBDRAGON:"
	@echo "  INC     = $(DRAGON_INC)"
	@echo "  LIBDIR  = $(DRAGON_LIBDIR)"
	@echo "  LDSCRIPT= $(N64_LDSCRIPT)"
	@echo "SOURCES = $(SOURCES)"

# Fail fast if main missing/duplicated
precheck:
	@set -e; \
	test -f $(SRC_DIR)/main.c || { echo "ERROR: $(SRC_DIR)/main.c missing"; exit 1; }; \
	COUNT=$$(grep -R --include='*.c' -n "^[[:space:]]*int[[:space:]]\\+main[[:space:]]*(" $(SRC_DIR) 2>/dev/null | wc -l); \
	if [ "$$COUNT" -eq 0 ]; then echo "ERROR: No int main(...) found under $(SRC_DIR)/"; exit 1; fi; \
	if [ "$$COUNT" -gt 1 ]; then echo "ERROR: More than one file defines main()"; grep -R --include='*.c' -n "^[[:space:]]*int[[:space:]]\\+main[[:space:]]*(" $(SRC_DIR) || true; exit 1; fi; \
	echo "OK: exactly one main()."

# Compile
$(SRC_DIR)/%.o: $(SRC_DIR)/%.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

# Link ELF
$(ELF): $(OBJS)
	@echo "  [LD]  $(ELF)"
	$(CC) -o $@ $(OBJS) $(LDFLAGS)

# Single-argument n64elfcompress support:
# Many runners ship a variant that wants ONLY the ELF and writes <ELF>.bin64 next to it.
define DO_SINGLE_ARG_COMPRESS
rm -f "$(BIN64)"; \
$(N64ELFCOMPRESS) "$(ELF)" || exit 1; \
if [ ! -s "$(BIN64)" ]; then \
  # Some builds write <basename>.bin64 with full input path – catch both
  B="$$(basename "$(ELF)")"; \
  if [ -s "$${B}.bin64" ]; then mv -f "$${B}.bin64" "$(BIN64)"; fi; \
fi; \
[ -s "$(BIN64)" ]
endef

# Produce BIN64 robustly:
#  1) Try the single-argument variant (produces <ELF>.bin64)
#  2) If that fails, try two-argument styles in both orders (older variants)
$(BIN64): $(ELF)
	@echo "  [ELF->BIN64] $(BIN64)"
	@set -e; \
	if command -v $(N64ELFCOMPRESS) >/dev/null 2>&1; then \
	  echo "    TRY: n64elfcompress (single-arg)"; \
	  if ( $(DO_SINGLE_ARG_COMPRESS) ); then \
	    echo "    OK: produced $(BIN64) via single-arg mode"; \
	  else \
	    echo "    Single-arg mode did not produce $(BIN64); trying 2-arg fallbacks"; \
	    rm -f "$(BIN64)"; \
	    if $(N64ELFCOMPRESS) "$(ELF)" "$(BIN64)" 2>compress.err; then :; else \
	      if grep -qi "error opening input file: $(BIN64)\|error loading ELF file: $(BIN64)" compress.err; then \
	        echo "    Detected reversed arg order; retrying as: n64elfcompress BIN64 ELF"; \
	        $(N64ELFCOMPRESS) "$(BIN64)" "$(ELF)"; \
	      else \
	        echo "n64elfcompress failed:"; cat compress.err; rm -f compress.err; exit 1; \
	      fi; \
	    fi; rm -f compress.err; \
	    [ -s "$(BIN64)" ] || { echo "ERROR: $(BIN64) not produced"; exit 1; } \
	  fi; \
	else \
	  echo "ERROR: n64elfcompress not found"; exit 1; \
	fi

# ROM filesystem (safe even if empty)
$(DFS): | $(ASSETS_DIR)
	@if [ -z "$$(find $(ASSETS_DIR) -type f -not -name '.keep' -print -quit)" ]; then \
		echo "ROMFS empty; creating placeholder"; \
		printf "ROMFS placeholder.\n" > $(ASSETS_DIR)/readme.txt; \
	fi
	@echo "  [DFS] $(DFS)"
	mkdfs $(DFS) $(ASSETS_DIR)

$(ASSETS_DIR):
	@mkdir -p $(ASSETS_DIR)
	@touch $(ASSETS_DIR)/.keep

# ---- Pack ROM:
# First, try letting n64tool eat the ELF directly (newer toolchains).
# If that fails, fall back to the BIN64 path we prepared above.
$(ROM): $(ELF) $(DFS)
	@echo "  [ROM] $(ROM)"
	@set -e; \
	ok_pack() { [ -s "$(ROM)" ]; }; \
	rm -f "$(ROM)"; \
	# Attempt 1: direct ELF -> ROM
	echo "    TRY: n64tool (ELF directly)"; \
	if $(N64TOOL) -l $(ROMSIZE) -t "$(TITLE)" -T -o "$(ROM)" "$(ELF)" -a 4 $(DFS) 2>pack.err; then :; fi; \
	if ok_pack; then echo "    OK: packed ROM from ELF"; rm -f pack.err; $(MAKE) -s fixcrc; exit 0; fi; \
	# Attempt 2: go through BIN64
	echo "    Fallback: via BIN64"; \
	$(MAKE) -s $(BIN64); \
	$(N64TOOL) -l $(ROMSIZE) -t "$(TITLE)" -T -o "$(ROM)" "$(BIN64)" -a 4 $(DFS); \
	ok_pack || { echo "ERROR: n64tool did not create $(ROM)"; cat pack.err 2>/dev/null || true; exit 1; }; \
	rm -f pack.err; \
	$(MAKE) -s fixcrc

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
		echo "[WARN] No checksum tool; skipping CRC fix."; \
	fi

# Verify ROM header & report size
verifyrom:
	@printf "  [MAGIC] "; xxd -l 4 -g 1 "$(ROM)" | awk 'NR==1{print $$2, $$3, $$4, $$5}'
	@HEAD=$$(xxd -l 4 -p "$(ROM)"); \
	if [ "$$HEAD" != "80371240" ]; then \
		echo "ERROR: ROM magic $$HEAD != 80371240 (.z64 big-endian)"; exit 1; \
	fi
	@echo "  [SIZE] $$(wc -c < "$(ROM)") bytes"; ls -lh "$(ROM)"

clean:
	@echo "  [CLEAN]"
	@$(RM) -f $(OBJS) $(ELF) $(BIN64) $(DFS) $(ROM) $(ASSETS_DIR)/readme.txt

distclean: clean
	@echo "  [DISTCLEAN]"
