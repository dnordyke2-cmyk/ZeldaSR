N64_INST ?= /opt/libdragon
CC       := $(N64_INST)/bin/mips64-elf-gcc
CFLAGS   := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections -I$(N64_INST)/mips64-elf/include
LDFLAGS  := -T $(N64_INST)/mips64-elf/lib/n64.ld -L$(N64_INST)/mips64-elf/lib -ldragon -lc -lm -ldragonsys -Wl,--gc-sections

N64TOOL        := $(N64_INST)/bin/n64tool
N64ELFCOMPRESS := $(N64_INST)/bin/n64elfcompress
MKDFS          := $(N64_INST)/bin/mkdfs

TITLE := Shattered Realms
OUT   := shattered_realms
SRC   := src/main.c
OBJ   := $(SRC:.c=.o)

ROMFS_DIR := assets/romfs
DFS       := romfs.dfs
ROMSIZE   := 2M

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

%.o: %.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(OUT).elf: $(OBJ)
	@echo "  [LD]  $@"
	$(CC) -o $@ $(OBJ) $(LDFLAGS)

$(OUT).bin64: $(OUT).elf
	@echo "  [ELF->BIN64] $@"
	@set -e; \
	$(N64ELFCOMPRESS) $(OUT).elf || true; \
	if [ -f "$(OUT).elf.bin" ]; then mv -f "$(OUT).elf.bin" "$(OUT).bin64"; fi; \
	if [ ! -f "$(OUT).bin64" ]; then $(N64ELFCOMPRESS) $(OUT).elf $(OUT).bin64; fi; \
	[ -f "$(OUT).bin64" ] || { echo "ERROR: $(OUT).bin64 not produced"; exit 1; }

$(DFS):
	@mkdir -p $(ROMFS_DIR)
	@if [ -z "$$(ls -A $(ROMFS_DIR) 2>/dev/null)" ]; then \
	  echo "ROMFS empty; creating placeholder"; \
	  echo "This is your ROM filesystem." > $(ROMFS_DIR)/readme.txt; \
	fi
	@echo "  [DFS] $@"
	$(MKDFS) $@ $(ROMFS_DIR)

$(OUT).z64: $(OUT).bin64 $(DFS)
	@echo "  [ROM] $@"
	$(N64TOOL) -o $@ -t "$(TITLE)" -l $(ROMSIZE) $(OUT).bin64 -a 4 $(DFS)

clean:
	@echo "  [CLEAN]"
	@rm -f $(OBJ) $(OUT).elf $(OUT).bin64 $(DFS)

distclean: clean
	@echo "  [DISTCLEAN]"
	@rm -f $(OUT).z64
