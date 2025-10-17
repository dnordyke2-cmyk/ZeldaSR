# ====== Portable Libdragon toolchain detection ======
# We assume either:
#   A) /opt/libdragon/mips64-elf/{include,lib}     (official libdragon images)
#   B) /n64_toolchain/mips64-elf/{include,lib}     (some toolchain-only images)
# We detect both at build time.

# Preferred install root (can override via env)
N64_INST ?= /opt/libdragon

# Resolve include, lib, and linker script dynamically
DRAGON_INC := $(shell \
  if [ -d "$(N64_INST)/mips64-elf/include" ]; then echo "$(N64_INST)/mips64-elf/include"; \
  elif [ -d "/n64_toolchain/mips64-elf/include" ]; then echo "/n64_toolchain/mips64-elf/include"; \
  else echo ""; fi)

DRAGON_LIBDIR := $(shell \
  if [ -d "$(N64_INST)/mips64-elf/lib" ]; then echo "$(N64_INST)/mips64-elf/lib"; \
  elif [ -d "/n64_toolchain/mips64-elf/lib" ]; then echo "/n64_toolchain/mips64-elf/lib"; \
  else echo ""; fi)

N64_LDSCRIPT := $(shell \
  if [ -f "$(N64_INST)/mips64-elf/lib/n64.ld" ]; then echo "$(N64_INST)/mips64-elf/lib/n64.ld"; \
  elif [ -f "/n64_toolchain/mips64-elf/lib/n64.ld" ]; then echo "/n64_toolchain/mips64-elf/lib/n64.ld"; \
  else echo ""; fi)

# Fail early with a helpful message if headers/libs are truly missing
ifeq ($(strip $(DRAGON_INC)),)
$(error Could not find libdragon headers. Looked in $(N64_INST)/mips64-elf/include and /n64_toolchain/mips64-elf/include)
endif
ifeq ($(strip $(DRAGON_LIBDIR)),)
$(error Could not find libdragon libraries. Looked in $(N64_INST)/mips64-elf/lib and /n64_toolchain/mips64-elf/lib)
endif
ifeq ($(strip $(N64_LDSCRIPT)),)
$(error Could not find n64.ld. Looked in $(N64_INST)/mips64-elf/lib and /n64_toolchain/mips64-elf/lib)
endif

# ====== Compiler/toolchain from PATH (portable) ======
MIPS_PREFIX ?= mips64-elf
CC := $(MIPS_PREFIX)-gcc
AR := $(MIPS_PREFIX)-ar

# ====== Project settings ======
TITLE    := Shattered Realms
ROM      := shattered_realms.z64
ELF      := shattered_realms.elf
ROMSIZE  := 2M
HEADER   := $(N64_INST)/lib/header  # HEADER usually exists under /opt/libdragon/lib; harmless if container provides a default inside n64tool

# ====== Layout ======
SRC_DIR    := src
ASSETS_DIR := assets/romfs
DFS        := romfs.dfs

SRCS := $(wildcard $(SRC_DIR)/*.c)
OBJS := $(SRCS:.c=.o)

# ====== Flags ======
CFLAGS  := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections \
           -I$(DRAGON_INC)

LDFLAGS := -T $(N64_LDSCRIPT) \
           -L$(DRAGON_LIBDIR) -ldragon -lc -lm -ldragonsys \
           -Wl,--gc-sections

# ====== Phony ======
.PHONY: all clean distclean run fixcrc

all: $(ROM)

# ====== Compile ======
$(SRC_DIR)/%.o: $(SRC_DIR)/%.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

# ====== Link ======
$(ELF): $(OBJS)
	@echo "  [LD]  $(ELF)"
	$(CC) -o $@ $(OBJS) $(LDFLAGS)

# ====== DFS (safe even if empty) ======
$(DFS): | $(ASSETS_DIR)
	@if [ -z "$$(find $(ASSETS_DIR) -type f -not -name '.keep' -print -quit)" ]; then \
		echo "ROMFS is empty; creating placeholder readme.txt"; \
		printf "ROMFS placeholder. Add assets here (sprites, text, etc.).\n" > $(ASSETS_DIR)/readme.txt; \
	fi
	@echo "  [DFS] $(DFS)"
	mkdfs $(DFS) $(ASSETS_DIR)

$(ASSETS_DIR):
	@mkdir -p $(ASSETS_DIR)
	@touch $(ASSETS_DIR)/.keep

# ====== ROM + CRC ======
$(ROM): $(ELF) $(DFS)
	@echo "  [ROM] $(ROM)"
	# ELF MUST be first; no offset on the first file.
	n64tool -l $(ROMSIZE) -t "$(TITLE)" -h "$(HEADER)" -o "$(ROM)" "$(ELF)" -a 4 $(DFS)
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
		echo "  [WARN] No checksum tool found (chksum64/rn64crc/n64crc). Skipping CRC fix."; \
	fi

# ====== Utilities ======
clean:
	@echo "  [CLEAN]"
	@$(RM) -f $(OBJS) $(ELF) $(DFS)

distclean: clean
	@echo "  [DISTCLEAN]"
	@$(RM) -f $(ROM)
	@$(RM) -f $(ASSETS_DIR)/readme.txt

run: $(ROM)
	@echo "  [RUN] $(ROM)"
	@echo "Supply your emulator command here, e.g.: ares $(ROM)"
