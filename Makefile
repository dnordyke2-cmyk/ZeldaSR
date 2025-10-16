# -------------------------------------------------------------
# Zelda: Shattered Realms — Minimal Alpha Build (libdragon 3.x)
# -------------------------------------------------------------

# Toolchain
N64_PREFIX := mips64-elf-
CC         := $(N64_PREFIX)gcc

# Environment paths (libdragon installed by workflow)
N64_INST   ?= /home/runner/.local/libdragon
LIBDRAGON  := $(N64_INST)
INCLUDES   := -I$(LIBDRAGON)/include
LIBS       := -L$(LIBDRAGON)/lib -ldragon -lm

# Project sources
SRCS       := src/main.c src/hud.c src/dungeon.c src/combat.c src/audio.c
OBJS       := $(SRCS:.c=.o)

# Outputs
TARGET_ELF := shattered_realms.elf
TARGET_ROM := shattered_realms.z64
ROMFS      := assets/romfs

# Flags
CFLAGS  := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections $(INCLUDES)
LDFLAGS := -T $(LIBDRAGON)/lib/n64.ld $(LIBS)

# Default
all: $(TARGET_ROM)

$(TARGET_ELF): $(OBJS)
	@echo "  [LD]  $@"
	$(CC) -o $@ $(OBJS) $(LDFLAGS)

$(TARGET_ROM): $(TARGET_ELF)
	@echo "  [ROM] $@"
	mkdfs $(ROMFS) romfs.dfs
	n64tool -l 2M -t "Shattered Realms" -h $(LIBDRAGON)/lib/header -o $@ $< -s 1M -B romfs.dfs
	chksum64 $@

%.o: %.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	@echo "  [CLEAN]"
	rm -f $(OBJS) $(TARGET_ELF) $(TARGET_ROM) romfs.dfs

.PHONY: all clean
