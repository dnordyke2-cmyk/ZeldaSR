# ===============================
# Zelda: Shattered Realms Makefile — multi-pack matrix
# Builds 3 ROMs: TOC (modern), LEGACY (no TOC), BIN-first
# ===============================

N64_INST    ?= /opt/libdragon
MIPS_PREFIX ?= mips64-elf
CC          := $(MIPS_PREFIX)-gcc
OBJCOPY     := $(MIPS_PREFIX)-objcopy

TITLE   := Shattered Realms
ELF     := shattered_realms.elf
BIN     := shattered_realms.bin
DFS     := romfs.dfs

# Three outputs so we can compare behavior in Ares/OpenEmu
ROM_TOC     := shattered_realms_toc.z64
ROM_LEGACY  := shattered_realms_legacy.z64
ROM_BIN     := shattered_realms_bin.z64

ROMSIZE := 2M

SRC_DIR    := src
ASSETS_DIR := assets/romfs

SRCS := $(wildcard $(SRC_DIR)/*.c)
OBJS := $(SRCS:.c=.o)

# --- Locate libdragon bits ---
DRAGON_INC := $(shell \
  if [ -d "$(N64_INST)/mips64-elf/include" ]; then echo "$(N64_INST)/mips64-elf/include"; \
  elif [ -d "/n64_toolchain/mips64-elf/include" ]; then echo "/n64_toolchain/mips64-elf/include"; fi)

DRAGON_LIBDIR := $(shell \
  if [ -d "$(N64_INST)/mips64-elf/lib" ]; then echo "$(N64_INST)/mips64-elf/lib"; \
  elif [ -d "/n64_toolchain/mips64-elf/lib" ]; then echo "/n64_toolchain/mips64-elf/lib"; fi)

N64_LDSCRIPT := $(shell \
  if [ -f "$(N64_INST)/mips64-elf/lib/n64.ld" ]; then echo "$(N64_INST)/mips64-elf/lib/n64.ld"; \
  elif [ -f "/n64_toolchain/mips64-elf/lib/n64.ld" ]; then echo "/n64_toolchain/mips64-elf/lib/n64.ld"; fi)

ifeq ($(strip $(DRAGON_INC)),)
$(error Could not find libdragon headers. Looked in $(N64_INST)/mips64-elf/include and /n64_toolchain/mips64-elf/include)
endif
ifeq ($(strip $(DRAGON_LIBDIR)),)
$(error Could not find libdragon libraries. Looked in $(N64_INST)/mips64-elf/lib and /n64_toolchain/mips64-elf/lib)
endif
ifeq ($(strip $(N64_LDSCRIPT)),)
$(error Could not find n64.ld. Looked in $(N64_INST)/mips64-elf/lib and /n64_toolchain/mips64-elf/lib)
endif

CFLAGS  := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections \
           -I$(DRAGON_INC)
LDFLAGS := -T $(N64_LDSCRIPT) \
           -L$(DRAGON_LIBDIR) -ldragon -lc -lm -ldragonsys \
           -Wl,--gc-sections

.PHONY: all clean distclean run showpaths fixcrc verifyroms

all: $(ROM_TOC) $(ROM_LEGACY) $(ROM_BIN)

showpaths:
	@echo "INC=$(DRAGON_INC)"
	@echo "LIBDIR=$(DRAGON_LIBDIR)"
	@echo "LDSCRIPT=$(N64_LDSCRIPT)"

# --- Compile & link ---
$(SRC_DIR)/%.o: $(SRC_DIR)/%.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(ELF): $(OBJS)
	@echo "  [LD]  $(ELF)"
	$(CC) -o $@ $(OBJS) $(LDFLAGS)

# --- BIN (raw program image) ---
$(BIN): $(ELF)
	@echo "  [BIN] $(BIN)"
	$(OBJCOPY) -O binary $(ELF) $(BIN)

# --- ROMFS (safe even if empty) ---
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

# --- Pack 1: TOC build (modern flow: ELF + -T + DFS) ---
$(ROM_TOC): $(ELF) $(DFS)
	@echo "  [ROM] $(ROM_TOC)"
	n64tool -l $(ROMSIZE) -t "$(TITLE)" -R E -C N -T -o "$(ROM_TOC)" "$(ELF)" -a 4 $(DFS)
	@if [ ! -s "$(ROM_TOC)" ]; then echo "ERROR: n64tool did not create $(ROM_TOC)"; exit 1; fi
	@$(MAKE) -s fixcrc ROM="$(ROM_TOC)"

# --- Pack 2: LEGACY build (ELF + DFS; NO -T) ---
$(ROM_LEGACY): $(ELF) $(DFS)
	@echo "  [ROM] $(ROM_LEGACY)"
	n64tool -l $(ROMSIZE) -t "$(TITLE)" -R E -C N -o "$(ROM_LEGACY)" "$(ELF)" -a 4 $(DFS)
	@if [ ! -s "$(ROM_LEGACY)" ]; then echo "ERROR: n64tool did not create $(ROM_LEGACY)"; exit 1; fi
	@$(MAKE) -s fixcrc ROM="$(ROM_LEGACY)"

# --- Pack 3: BIN-first (BIN + DFS) ---
$(ROM_BIN): $(BIN) $(DFS)
	@echo "  [ROM] $(ROM_BIN)"
	n64tool -l $(ROMSIZE) -t "$(TITLE)" -R E -C N -o "$(ROM_BIN)" "$(BIN)" -a 4 $(DFS) || true
	@if [ ! -s "$(ROM_BIN)" ]; then echo "ERROR: n64tool did not create $(ROM_BIN)"; exit 1; fi
	@$(MAKE) -s fixcrc ROM="$(ROM_BIN)"

# --- CRC (best-effort) ---
fixcrc:
	@set -e; \
	if command -v chksum64 >/dev/null 2>&1; then \
		echo "  [CRC] chksum64 $(ROM)"; chksum64 "$(ROM)" >/dev/null; \
	elif command -v rn64crc >/dev/null 2>&1; then \
		echo "  [CRC] rn64crc -u $(ROM)"; rn64crc -u "$(ROM)"; \
	elif command -v n64crc >/dev/null 2>&1; then \
		echo "  [CRC] n64crc $(ROM)"; n64crc "$(ROM)"; \
	else \
		echo "[WARN] No checksum tool found; skipping CRC fix for $(ROM)."; \
	fi

# --- Verify headers for all ROMs ---
verifyroms: $(ROM_TOC) $(ROM_LEGACY) $(ROM_BIN)
	@for r in $(ROM_TOC) $(ROM_LEGACY) $(ROM_BIN); do \
		printf "  [MAGIC] $$r  : "; \
		xxd -l 4 -g 1 "$$r" | awk 'NR==1{print $$2, $$3, $$4, $$5}'; \
	done

clean:
	@echo "  [CLEAN]"
	@$(RM) -f $(OBJS) $(ELF) $(BIN) $(DFS)

distclean: clean
	@echo "  [DISTCLEAN]"
	@$(RM) -f $(ROM_TOC) $(ROM_LEGACY) $(ROM_BIN)
	@$(RM) -f $(ASSETS_DIR)/readme.txt

# Convenience: run default pick (TOC) in local env
run: $(ROM_TOC)
	@echo "  [RUN] $(ROM_TOC)"
