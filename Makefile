# ===========================
# ZeldaSR — clean Makefile
# ===========================
N64_INST    ?= /opt/libdragon
MIPS_PREFIX ?= mips64-elf

CC := $(MIPS_PREFIX)-gcc

# Libdragon paths
DRAGON_INC    := $(firstword $(wildcard $(N64_INST)/mips64-elf/include) /n64_toolchain/mips64-elf/include)
DRAGON_LIBDIR := $(firstword $(wildcard $(N64_INST)/mips64-elf/lib)     /n64_toolchain/mips64-elf/lib)
N64_LDSCRIPT  := $(firstword $(wildcard $(N64_INST)/mips64-elf/lib/n64.ld) /n64_toolchain/mips64-elf/lib/n64.ld)

# Tools (we *require* n64elf2bin; the workflow below will ensure it exists)
N64ELF2BIN ?= n64elf2bin
N64TOOL    ?= n64tool# ===== Shattered Realms — libdragon Makefile (stable) =====

# --- Paths (GitHub runner installs toolchain to /opt/libdragon) ---
N64_INST ?= /opt/libdragon
CC       := $(N64_INST)/bin/mips64-elf-gcc
CFLAGS   := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections -I$(N64_INST)/mips64-elf/include
LDFLAGS  := -T $(N64_INST)/mips64-elf/lib/n64.ld -L$(N64_INST)/mips64-elf/lib -ldragon -lc -lm -ldragonsys -Wl,--gc-sections

# Tools (we build+install these in the workflow)
N64TOOL       := $(N64_INST)/bin/n64tool
N64ELFCOMPRESS:= $(N64_INST)/bin/n64elfcompress
MKDFS         := $(N64_INST)/bin/mkdfs

# --- Project ---
TITLE := Shattered Realms
OUT   := shattered_realms
SRC   := src/main.c               # start simple; add more *.c later
OBJ   := $(SRC:.c=.o)

ROMFS_DIR := assets/romfs
DFS      := romfs.dfs

# ROM size (can omit; keeping 2M is safe for tiny demos)
ROMSIZE := 2M

# --- Phony targets ---
.PHONY: all clean distclean showpaths

all: $(OUT).z64

showpaths:
	@echo "TOOLCHAIN:"
	@echo "  CC  = $(CC)"
	@echo "TOOLS:"
	@printf "  n64elfcompress = "; command -v $(N64ELFCOMPRESS) || echo MISSING
	@printf "  n64tool        = "; command -v $(N64TOOL)        || echo MISSING
	@printf "  mkdfs          = "; command -v $(MKDFS)          || echo MISSING
	@echo "LIBDRAGON:"
	@echo "  INC     = $(N64_INST)/mips64-elf/include"
	@echo "  LIBDIR  = $(N64_INST)/mips64-elf/lib"
	@echo "  LDSCRIPT= $(N64_INST)/mips64-elf/lib/n64.ld"
	@echo "SOURCES = $(SRC)"

# --- Build rules ---
%.o: %.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(OUT).elf: $(OBJ)
	@echo "  [LD]  $@"
	$(CC) -o $@ $(OBJ) $(LDFLAGS)

# Convert ELF → BIN64
# n64elfcompress has 2 modes:
#   1) Single-arg: `n64elfcompress foo.elf` -> creates `foo.elf.bin`
#   2) Two-arg   : `n64elfcompress in.elf out.bin64`
# We prefer single-arg, then rename to $(OUT).bin64.
$(OUT).bin64: $(OUT).elf
	@echo "  [ELF->BIN64] $@"
	@set -e; \
	$(N64ELFCOMPRESS) $(OUT).elf || true; \
	if [ -f "$(OUT).elf.bin" ]; then \
	  mv -f "$(OUT).elf.bin" "$(OUT).bin64"; \
	fi; \
	if [ ! -f "$(OUT).bin64" ]; then \
	  $(N64ELFCOMPRESS) $(OUT).elf $(OUT).bin64; \
	fi; \
	[ -f "$(OUT).bin64" ] || { echo "ERROR: $(OUT).bin64 not produced"; exit 1; }

# Ensure ROMFS exists (mkdfs fails on empty dirs)
$(DFS):
	@mkdir -p $(ROMFS_DIR)
	@if [ -z "$$(ls -A $(ROMFS_DIR) 2>/dev/null)" ]; then \
	  echo "ROMFS empty; creating placeholder"; \
	  echo "This is your ROM filesystem." > $(ROMFS_DIR)/readme.txt; \
	fi
	@echo "  [DFS] $@"
	$(MKDFS) $@ $(ROMFS_DIR)

# Pack the ROM: FIRST file MUST be the BIN64 payload.
$(OUT).z64: $(OUT).bin64 $(DFS)
	@echo "  [ROM] $@"
	$(N64TOOL) \
	  -o $@ \
	  -t "$(TITLE)" \
	  -l $(ROMSIZE) \
	  $(OUT).bin64 \
	  -a 4 $(DFS)

clean:
	@echo "  [CLEAN]"
	@rm -f $(OBJ) $(OUT).elf $(OUT).bin64 $(DFS)

distclean: clean
	@echo "  [DISTCLEAN]"
	@rm -f $(OUT).z64

MKDFS      ?= mkdfs

TITLE   := Shattered Realms
ROMSIZE := 2M

SRC_DIR    := src
ASSETS_DIR := assets/romfs

ELF   := shattered_realms.elf
BIN64 := shattered_realms.bin64
ROM   := shattered_realms.z64
DFS   := romfs.dfs

SOURCES := $(SRC_DIR)/main.c
OBJS    := $(SOURCES:.c=.o)

# Hard fails if libdragon isn’t installed
ifeq ($(strip $(DRAGON_INC)),)
  $(error libdragon headers missing (looked in $(N64_INST)/mips64-elf/include and /n64_toolchain/mips64-elf/include))
endif
ifeq ($(strip $(DRAGON_LIBDIR)),)
  $(error libdragon libs missing (looked in $(N64_INST)/mips64-elf/lib and /n64_toolchain/mips64-elf/lib))
endif
ifeq ($(strip $(N64_LDSCRIPT)),)
  $(error n64.ld missing in $(N64_INST)/mips64-elf/lib or /n64_toolchain/mips64-elf/lib)
endif

CFLAGS  := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections -I$(DRAGON_INC)
LDFLAGS := -T $(N64_LDSCRIPT) -L$(DRAGON_LIBDIR) -ldragon -lc -lm -ldragonsys -Wl,--gc-sections

.PHONY: all clean distclean showpaths verifyrom fixcrc

all: $(ROM)

showpaths:
	@echo "--- Makefile paths ---"
	@echo "TOOLCHAIN:"
	@echo "  CC  = $$(command -v $(CC)  || echo 'MISSING')"
	@echo "TOOLS:"
	@echo "  n64elf2bin = $$(command -v $(N64ELF2BIN) || echo 'MISSING')"
	@echo "  n64tool    = $$(command -v $(N64TOOL)    || echo 'MISSING')"
	@echo "  mkdfs      = $$(command -v $(MKDFS)      || echo 'MISSING')"
	@echo "LIBDRAGON:"
	@echo "  INC     = $(DRAGON_INC)"
	@echo "  LIBDIR  = $(DRAGON_LIBDIR)"
	@echo "  LDSCRIPT= $(N64_LDSCRIPT)"
	@echo "SOURCES = $(SOURCES)"
	@echo "----------------------"

$(SRC_DIR)/%.o: $(SRC_DIR)/%.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(ELF): $(OBJS)
	@echo "  [LD]  $(ELF)"
	$(CC) -o $@ $(OBJS) $(LDFLAGS)

$(BIN64): $(ELF)
	@echo "  [ELF->BIN64] $(BIN64)"
	@command -v $(N64ELF2BIN) >/dev/null 2>&1 || { \
		echo "ERROR: n64elf2bin not found on PATH"; exit 1; }
	$(N64ELF2BIN) "$(ELF)" -o "$(BIN64)" || $(N64ELF2BIN) "$(ELF)" "$(BIN64)"
	@[ -s "$(BIN64)" ] || { echo "ERROR: $(BIN64) not produced"; exit 1; }

$(ASSETS_DIR):
	@mkdir -p $@
	@touch $(ASSETS_DIR)/.keep

$(DFS): | $(ASSETS_DIR)
	@if [ -z "$$(find $(ASSETS_DIR) -type f -not -name '.keep' -print -quit)" ]; then \
		echo "ROMFS empty; creating placeholder"; \
		printf "ROMFS placeholder.\n" > $(ASSETS_DIR)/readme.txt; \
	fi
	@echo "  [DFS] $(DFS)"
	$(MKDFS) $(DFS) $(ASSETS_DIR)

$(ROM): $(BIN64) $(DFS)
	@echo "  [ROM] $(ROM)"
	$(N64TOOL) -l $(ROMSIZE) -t "$(TITLE)" -T -o "$(ROM)" "$(BIN64)" -a 4 $(DFS)
	@$(MAKE) -s fixcrc
	@$(MAKE) -s verifyrom

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
