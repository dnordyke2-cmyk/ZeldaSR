# --------------------------------------------------------------------
# Zelda: Shattered Realms  (Minimal Alpha)
# Compatible with libdragon 3.x and mips64-elf toolchain
# --------------------------------------------------------------------

# Toolchain
N64_PREFIX  := mips64-elf-
CC          := $(N64_PREFIX)gcc
LD          := $(N64_PREFIX)ld
OBJCOPY     := $(N64_PREFIX)objcopy

# Paths
N64_INST    ?= /opt/libdragon
LIBDRAGON   := $(N64_INST)
INCLUDES    := -I$(LIBDRAGON)/include
LIBS        := -L$(LIBDRAGON)/lib -ldragon -lm

# Project files
SRCS        := src/main.c src/hud.c src/dungeon.c src/combat.c src/audio.c
OBJS        := $(SRCS:.c=.o)
TARGET_ELF  := shattered_realms.elf
TARGET_ROM  := shattered_realms.z64
ROMFS       := assets/romfs

# Compiler flags
CFLAGS  := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections $(INCLUDES)
LDFLAGS := -T $(LIBDRAGON)/lib/n64.ld -L$(LIBDRAGON)/lib $(LIBS)

# --------------------------------------------------------------------
# Rules
# --------------------------------------------------------------------

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

# --------------------------------------------------------------------
# Convenience
# --------------------------------------------------------------------
.PHONY: all clean
