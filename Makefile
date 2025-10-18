# ===============================
# Zelda: Shattered Realms Makefile
# ===============================

N64_INST ?= /opt/libdragon
MIPS_PREFIX ?= mips64-elf
CC := $(MIPS_PREFIX)-gcc
AR := $(MIPS_PREFIX)-ar

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
  elif [ -d "/n64_toolchain/mips64-elf/include" ]; then echo "/n64_toolchain/mips64-elf/include"; \
  fi)

DRAGON_LIBDIR := $(shell \
  if [ -d "$(N64_INST)/mips64-elf/lib" ]; then echo "$(N64_INST)/mips64-elf/lib"; \
  elif [ -d "/n64_toolchain/mips64-elf/lib" ]; then echo "/n64_toolchain/mips64-elf/lib"; \
  fi)

N64_LDSCRIPT := $(shell \
  if [ -f "$(N64_INST)/mips64-elf/lib/n64.ld" ]; then echo "$(N64_INST)/mips64-elf/lib/n64.ld"; \
  elif [ -f "/n64_toolchain/mips64-elf/lib/n64.ld" ]; then echo "/n64_toolchain/mips64-elf/lib/n64.ld"; \
  fi)

# --- Require IPL3 header ---
HEADER_CANDIDATES := \
  $(N64_INST)/lib/header \
  $(N64_INST)/lib/ipl3.bin \
  $(N64_INST)/lib/ipl3_6102.bin \
  $(N64_INST)/mips64-elf/lib/header

HEADER_FILE := $(firstword $(foreach f,$(HEADER_CANDIDATES),$(if $(wildcard $(f)),$(f),)))
ifeq ($(HEADER_FILE),)
  $(error Missing IPL3 header (looked in $(N64_INST)/lib and friends). \
Run libdragon ./build.sh so that $(N64_INST)/lib/header exists.)
else
  $(info [INFO] Using IPL3 header: $(HEADER_FILE))
  HEADER_OPT := -h $(HEADER_FILE)
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
	@echo "HEADER_FILE=$(HEADER_FILE)"

$(SRC_DIR)/%.o: $(SRC_DIR)/%.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(ELF): $(OBJS)
	@echo "  [LD]  $(ELF)"
	$(CC) -o $@ $(OBJS) $(LDFLAGS)

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

$(ROM): $(ELF) $(DFS)
	@echo "  [ROM] $(ROM)"
	n64tool -l $(ROMSIZE) -t "$(TITLE)" $(HEADER_OPT) -o "$(ROM)" "$(ELF)" -a 4 $(DFS)
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
		echo "[WARN] No checksum tool found. Skipping CRC fix."; \
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
