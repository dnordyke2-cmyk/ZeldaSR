# ====== Libdragon / Toolchain roots ======
# Keep N64_INST for headers/libs (most containers install libs here).
N64_INST        ?= /opt/libdragon

# Use compiler from PATH (portable across images: /n64_toolchain/bin OR /opt/libdragon/bin)
MIPS_PREFIX     ?= mips64-elf
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
	@if [ -z "$$(find $(ASSETS_DIR) -type f -not -name '.keep' -print -quit)" ]; then \
		echo "ROMFS is empty; creating placeholder readme.txt"; \
		printf "ROMFS placeholder. Add assets here (sprites, text, etc.).\n" > $(ASSETS_DIR)/readme.txt; \
	fi
	@echo "  [DFS] $(DFS)"
	mkdfs $(DFS) $(ASSETS_DIR)

$(ASSETS_DIR):
	@mkdir -p $(ASSETS_DIR)
	@touch $(ASSETS_DIR)/.keep

# ====== ROM pack + checksum (with graceful fallbacks) ======
$(ROM): $(ELF) $(DFS)
	@echo "  [ROM] $(ROM)"
	@# ELF first; no offset on first file.
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
