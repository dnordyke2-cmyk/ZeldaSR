# ====== Libdragon / Toolchain roots ======
N64_INST        ?= /opt/libdragon
BIN             := $(N64_INST)/bin
MIPS_PREFIX     := $(N64_INST)/bin/mips64-elf

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
.PHONY: all clean distclean run

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
	@# Optional sentinel so the dir exists in VCS
	@touch $(ASSETS_DIR)/.keep

# ====== ROM pack + checksum ======
$(ROM): $(ELF) $(DFS)
	@echo "  [ROM] $(ROM)"
	@# IMPORTANT: First file (ELF) cannot have an offset; add DFS afterward.
	$(BIN)/n64tool -l $(ROMSIZE) -t "$(TITLE)" -h "$(HEADER)" -o "$(ROM)" "$(ELF)" -a 4 $(DFS)
	@# Fix CRC so emulators/hardware are happy.
	$(BIN)/chksum64 "$(ROM)" >/dev/null

# ====== Utilities ======
clean:
	@echo "  [CLEAN]"
	@$(RM) -f $(OBJS) $(ELF) $(DFS)

distclean: clean
	@echo "  [DISTCLEAN]"
	@$(RM) -f $(ROM)
	@# Keep assets but remove the placeholder if it was created
	@$(RM) -f $(ASSETS_DIR)/readme.txt

# (Optional) quick-run alias for your emulator of choice
run: $(ROM)
	@echo "  [RUN] $(ROM)"
	@echo "Supply your emulator command here, e.g.: ares $(ROM)"
