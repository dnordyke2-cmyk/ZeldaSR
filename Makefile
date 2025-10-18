# Zelda: Shattered Realms – minimal verified Makefile

N64_INST ?= /opt/libdragon
MIPS_PREFIX ?= mips64-elf
CC := $(MIPS_PREFIX)-gcc

TITLE   := Shattered Realms
ELF     := shattered_realms.elf
ROM     := shattered_realms.z64
DFS     := romfs.dfs
ROMSIZE := 2M

SRC_DIR := src
ASSETS  := assets/romfs
SRCS    := $(wildcard $(SRC_DIR)/*.c)
OBJS    := $(SRCS:.c=.o)

CFLAGS  := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections \
           -I$(N64_INST)/mips64-elf/include
LDFLAGS := -T $(N64_INST)/mips64-elf/lib/n64.ld \
           -L$(N64_INST)/mips64-elf/lib -ldragon -lc -lm -ldragonsys \
           -Wl,--gc-sections

all: $(ROM)

$(SRC_DIR)/%.o: $(SRC_DIR)/%.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(ELF): $(OBJS)
	@echo "  [LD]  $@"
	$(CC) -o $@ $^ $(LDFLAGS)

$(DFS):
	@mkdir -p $(ASSETS)
	@echo "ROMFS placeholder" > $(ASSETS)/readme.txt
	@echo "  [DFS]  $@"
	mkdfs $@ $(ASSETS)

$(ROM): $(ELF) $(DFS)
	@echo "  [ROM]  $@"
	n64tool -l $(ROMSIZE) -t "$(TITLE)" -o $@ $(ELF) -a 4 $(DFS)
	@if command -v chksum64 >/dev/null; then chksum64 $@ >/dev/null; fi
	@ls -lh $@

clean:
	rm -f $(SRC_DIR)/*.o $(ELF) $(DFS) $(ROM)
