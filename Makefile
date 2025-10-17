# ====== Libdragon / Toolchain roots ======
N64_INST        ?= /opt/libdragon
BIN             := $(N64_INST)/bin
MIPS_PREFIX     := $(BIN)/mips64-elf

CC              := $(MIPS_PREFIX)-gcc
AR              := $(MIPS_PREFIX)-ar

# ====== Project settings ======
TITLE           := Shattered Realms
ROM             := shattered_realms.z64
ELF             := shattered_realms.elf
ROMSIZE         := 2M
HEADER          := $(N64_INST)/lib/header

# Source layout
SRC_DIR         := src
ASSETS_DIR      := assets/romfs
DFS             := romfs.dfs

SRCS            := $(wildcard $(SRC_DIR)/*.c)
OBJS            := $(SRCS:.c=.o)

# ====== Flags ======
CFLAGS          := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections \
                   -I$(N64_INST)/mips64-elf/include

LDFLAGS         := -T $(N64_INST)/mips64-elf/lib/n64.ld \
                   -L$(N64_INST)/mips64-elf/lib -ldragon -lc -lm -ldragonsys \
                   -Wl,--gc-sections

# ====== Phony targets ======
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

# ====== DFS build (safe even if ROMFS is empty) ======
$(DFS): | $(ASSETS_DIR)
	@# Ensure ROMFS exists and is not functionally empty (mkdfs fails on empty dirs)
	@if [ -z "$$(find $(ASSETS_DIR) -type f -not -name '.keep' -print -quit)" ]; then \
		echo "ROMFS is empty; creating placeholder readme.txt"; \
		printf "ROMFS placeholder. Add assets here (sprites, text, etc.).\n" > $(ASSETS_DIR)/readme.txt; \
	fi
	@echo "  [DFS] $(DFS)"
	$(BIN)/mkdfs $(DFS) $(ASSETS_DIR)

$(ASSETS_DIR):
	@mkdir -p $(ASSETS_DIR)
	@touch $(ASSETS_DIR)/.keep

# ====== ROM pack + checksum (with graceful fallbacks) ======
$(ROM): $(ELF) $(DFS)
	@echo "  [ROM] $(ROM)"
	@# The ELF must be first; no offsets on the first file.
	$(BIN)/n64tool -l $(ROMSIZE) -t "$(TITLE)" -h "$(HEADER)" -o "$(ROM)" "$(ELF)" -a 4 $(DFS)
	@$(MAKE) -s fixcrc

# Try several checksum tools if available; otherwise warn and continue.
fixcrc:
	@set -e; \
	if [ -x "$(BIN)/chksum64" ]; then \
		echo "  [CRC] chksum64"; \
		"$(BIN)/chksum64" "$(ROM)" >/dev/null; \
	elif command -v rn64crc >/dev/null 2>&1; then \
		echo "  [CRC] rn64crc -u"; \
		rn64crc -u "$(ROM)"; \
	elif command -v n64crc >/dev/null 2>&1; then \
		echo "  [CRC] n64crc"; \
		n64crc "$(ROM)"; \
	else \
		echo "  [WARN] No checksum tool found (chksum64/rn64crc/n64crc). Skipping CRC fix."; \
		echo "        ROM will often still boot in modern emulators, but some carts/emus expect a fixed CRC."; \
	fi

# ====== Utilities ======
clean:
	@echo "  [CLEAN]"
	@$(RM) -f $(OBJS) $(ELF) $(DFS)

distclean: clean
	@echo "  [DISTCLEAN]"
	@$(RM) -f $(ROM)
	@$(RM) -f $(ASSETS_DIR)/readme.txt

# (Optional) quick-run alias for your emulator of choice
run: $(ROM)
	@echo "  [RUN] $(ROM)"
	@echo "Supply your emulator command here, e.g.: ares $(ROM)"
