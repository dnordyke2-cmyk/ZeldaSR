# ============================================================
# Zelda: Shattered Realms — stable build path
# Compile -> Link -> ELF --(n64elf2bin / n64elfcompress)--> BIN64 --(n64tool)--> ROM
# ============================================================

N64_INST    ?= /opt/libdragon
MIPS_PREFIX ?= mips64-elf

CC      := $(MIPS_PREFIX)-gcc
CXX     := $(MIPS_PREFIX)-g++
NM      := $(MIPS_PREFIX)-nm

N64ELF2BIN     ?= n64elf2bin
N64ELFCOMPRESS ?= n64elfcompress
N64TOOL        ?= n64tool
MKDFS          ?= mkdfs

TITLE   := Shattered Realms
ELF     := shattered_realms.elf
BIN64   := shattered_realms.bin64
ROM     := shattered_realms.z64
DFS     := romfs.dfs
ROMSIZE := 2M

SRC_DIR    := src
ASSETS_DIR := assets/romfs

SOURCES := $(SRC_DIR)/main.c
OBJS    := $(SOURCES:.c=.o)

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

showpaths:
	@echo "TOOLCHAIN:"
	@echo "  CC  = $$(command -v $(CC)  || echo 'MISSING')"
	@echo "  CXX = $$(command -v $(CXX) || echo 'MISSING')"
	@echo "  NM  = $$(command -v $(NM)  || echo 'MISSING')"
	@echo "TOOLS:"
	@echo "  n64elfcompress = $$(command -v $(N64ELFCOMPRESS) || echo 'MISSING')"
	@echo "  n64elf2bin     = $$(command -v $(N64ELF2BIN) || echo 'MISSING')"
	@echo "  n64tool        = $$(command -v $(N64TOOL) || echo 'MISSING')"
	@echo "LIBDRAGON:"
	@echo "  INC     = $(DRAGON_INC)"
	@echo "  LIBDIR  = $(DRAGON_LIBDIR)"
	@echo "  LDSCRIPT= $(N64_LDSCRIPT)"
	@echo "SOURCES = $(SOURCES)"

precheck:
	@set -e; \
	test -f $(SRC_DIR)/main.c || { echo "ERROR: $(SRC_DIR)/main.c missing"; exit 1; }; \
	COUNT=$$(grep -R --include='*.c' -n "^[[:space:]]*int[[:space:]]\\+main[[:space:]]*(" $(SRC_DIR) 2>/dev/null | wc -l); \
	if [ "$$COUNT" -eq 0 ]; then echo "ERROR: No int main(...) found under $(SRC_DIR)/"; exit 1; fi; \
	if [ "$$COUNT" -gt 1 ]; then echo "ERROR: More than one file defines main()"; grep -R --include='*.c' -n "^[[:space:]]*int[[:space:]]\\+main[[:space:]]*(" $(SRC_DIR) || true; exit 1; fi; \
	echo "OK: exactly one main()."

$(SRC_DIR)/%.o: $(SRC_DIR)/%.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(ELF): $(OBJS)
	@echo "  [LD]  $(ELF)"
	$(CC) -o $@ $(OBJS) $(LDFLAGS)

# Prefer n64elf2bin (handles already-compressed ELFs). Fallback to n64elfcompress variants.
$(BIN64): $(ELF)
	@echo "  [ELF->BIN64] $(BIN64)"
	@set -e; \
	if command -v $(N64ELF2BIN) >/dev/null 2>&1; then \
	  echo "    TRY: n64elf2bin"; \
	  # try common arg orders
	  $(N64ELF2BIN) "$(ELF)" -o "$(BIN64)" 2>/dev/null || \
	  $(N64ELF2BIN) -o "$(BIN64)" "$(ELF)" 2>/dev/null || \
	  $(N64ELF2BIN) "$(ELF)" "$(BIN64)"; \
	else \
	  echo "    n64elf2bin not found; using n64elfcompress fallbacks"; \
	  rm -f "$(BIN64)"; \
	  if command -v $(N64ELFCOMPRESS) >/dev/null 2>&1; then \
	    echo "    TRY: n64elfcompress (single-arg)"; \
	    $(N64ELFCOMPRESS) "$(ELF)" || true; \
	    if [ ! -s "$(BIN64)" ]; then \
	      B="$$(basename "$(ELF)")"; \
	      [ -s "$${B}.bin64" ] && mv -f "$${B}.bin64" "$(BIN64)"; \
	    fi; \
	    if [ ! -s "$(BIN64)" ]; then \
	      echo "    Single-arg mode didn’t produce $(BIN64); trying 2-arg fallbacks"; \
	      if $(N64ELFCOMPRESS) "$(ELF)" "$(BIN64)" 2>compress.err; then :; else \
	        if grep -qi "error opening input file: $(BIN64)\|error loading ELF file: $(BIN64)\|already compressed" compress.err; then \
	          echo "    Detected incompatible/duplicate compress; retry reversed order"; \
	          $(N64ELFCOMPRESS) "$(BIN64)" "$(ELF)" || true; \
	        else \
	          echo "n64elfcompress failed:"; cat compress.err; rm -f compress.err; exit 1; \
	        fi; \
	      fi; rm -f compress.err; \
	    fi; \
	  else \
	    echo "ERROR: neither n64elf2bin nor n64elfcompress found"; exit 1; \
	  fi; \
	fi; \
	[ -s "$(BIN64)" ] || { echo "ERROR: $(BIN64) not produced"; exit 1; }

$(DFS): | $(ASSETS_DIR)
	@if [ -z "$$(find $(ASSETS_DIR) -type f -not -name '.keep' -print -quit)" ]; then \
		echo "ROMFS empty; creating placeholder"; \
		printf "ROMFS placeholder.\n" > $(ASSETS_DIR)/readme.txt; \
	fi
	@echo "  [DFS] $(DFS)"
	$(MKDFS) $(DFS) $(ASSETS_DIR)

$(ASSETS_DIR):
	@mkdir -p $(ASSETS_DIR)
	@touch $(ASSETS_DIR)/.keep

# Always pack BIN64
$(ROM): $(BIN64) $(DFS)
	@echo "  [ROM] $(ROM)"
	$(N64TOOL) -l $(ROMSIZE) -t "$(TITLE)" -T -o "$(ROM)" "$(BIN64)" -a 4 $(DFS)
	@$(MAKE) -s fixcrc

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
