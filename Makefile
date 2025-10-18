# ===============================
# Zelda: Shattered Realms Makefile
# Auto IPL3 handling for all n64tool variants
# ===============================

N64_INST ?= /opt/libdragon
MIPS_PREFIX ?= mips64-elf
CC := $(MIPS_PREFIX)-gcc

TITLE    := Shattered Realms
ROM      := shattered_realms.z64
ELF      := shattered_realms.elf
ROMSIZE  := 2M

SRC_DIR    := src
ASSETS_DIR := assets/romfs
DFS        := romfs.dfs

SRCS := $(wildcard $(SRC_DIR)/*.c)
OBJS := $(SRCS:.c=.o)

# --- Detect libdragon include/lib/ldscript ---
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

# --- IPL3 strategy (handle all environments) ---
# 1) Prefer n64tool's --ipl3 if supported.
# 2) Otherwise try external header file.
# 3) Otherwise error out (do not silently emit a headerless ROM).
IPL3_SUPPORTED := $(shell (n64tool --help 2>/dev/null | grep -q -- '--ipl3') && echo yes || echo no)

HEADER_CANDIDATES := \
  $(N64_INST)/lib/header \
  $(N64_INST)/mips64-elf/lib/header
HEADER_FILE := $(firstword $(foreach f,$(HEADER_CANDIDATES),$(if $(wildcard $(f)),$(f),)))

ifeq ($(IPL3_SUPPORTED),yes)
  $(info [INFO] n64tool supports --ipl3; using built-in 6102.)
  IPL3_OPT := --ipl3 6102
else
  ifneq ($(strip $(HEADER_FILE)),)
    $(info [INFO] Using external IPL3 header: $(HEADER_FILE))
    IPL3_OPT := -h $(HEADER_FILE)
  else
    $(error Neither n64tool --ipl3 is supported nor an external header exists. \
Please install a libdragon snapshot with --ipl3 in n64tool OR place an IPL3 file at $(N64_INST)/lib/header)
  endif
endif

CFLAGS  := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections \
           -I$(DRAGON_INC)
LDFLAGS := -T $(N64_LDSCRIPT) \
           -L$(DRAGON_LIBDIR) -ldragon -lc -lm -ldragonsys \
           -Wl,--gc-sections

.PHONY: all clean distclean run fixcrc showpaths

all: $(ROM)

showpaths:
	@echo "INC=$(DRAGON_INC)"
	@echo "LIBDIR=$(DRAGON_LIBDIR)"
	@echo "LDSCRIPT=$(N64_LDSCRIPT)"
	@echo "IPL3_SUPPORTED=$(IPL3_SUPPORTED)"
	@echo "HEADER_FILE=$(or $(HEADER_FILE),<none>)"
	@echo "IPL3_OPT=$(IPL3_OPT)"

$(SRC_DIR)/%.o: $(SRC_DIR)/%.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(ELF): $(OBJS)
	@echo "  [LD]  $(ELF)"
	$(CC) -o $@ $(OBJS) $(LDFLAGS)

# --- DFS (safe even if empty) ---
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

# --- ROM pack + checksum (and verify output exists) ---
$(ROM): $(ELF) $(DFS)
	@echo "  [ROM] $(ROM)"
	n64tool -l $(ROMSIZE) -t "$(TITLE)" -o "$(ROM)" $(IPL3_OPT) "$(ELF)" -a 4 $(DFS)
	@if [ ! -s "$(ROM)" ]; then \
		echo "ERROR: n64tool did not create $(ROM). Check IPL3 options and n64tool version." >&2; \
		exit 1; \
	fi
	@$(MAKE) -s fixcrc
	@ls -lh "$(ROM)"

fixcrc:
	@set -e; \
	if command -v chksum64 >/dev/null 2>&1; then \
		echo "  [CRC] chksum64"; chksum64 "$(ROM)" >/dev/null; \
	elif command -v rn64crc >/dev/null 2>&1; then \
		echo "  [CRC] rn64crc -u"; rn64crc -u "$(ROM)"; \
	elif command -v n64crc >/dev/null 2>&1; then \
		echo "  [CRC] n64crc"; n64crc "$(ROM)"; \
	else \
		echo "[WARN] No checksum tool found (chksum64/rn64crc/n64crc). Skipping CRC fix."; \
	fi

clean:
	@echo "  [CLEAN]"
	@$(RM) -f $(OBJS) $(ELF) $(DFS)

distclean: clean
	@echo "  [DISTCLEAN]"
	@$(RM) -f $(ROM)
	@$(RM) -f $(ASSETS_DIR)/readme.txt

run: $(ROM)
	@echo "  [RUN] $(ROM)"
	@echo "Use your preferred emulator, e.g.: ares $(ROM)"
