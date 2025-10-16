# -------------------------------------------------------------
# Zelda: Shattered Realms — Minimal Alpha Build (libdragon 3.x)
# Target: Official libdragon .deb layout under /opt/libdragon
# -------------------------------------------------------------

# Toolchain
N64_PREFIX := mips64-elf-
CC         := $(N64_PREFIX)gcc

# Environment paths (installed by CI to /opt/libdragon)
N64_INST   ?= /opt/libdragon
LIBDRAGON  := $(N64_INST)

# NOTE: With the .deb toolchain, headers/libs are under mips64-elf/{include,lib}
INCLUDES   := -I$(LIBDRAGON)/mips64-elf/include
LIBDIR     := $(LIBDRAGON)/mips64-elf/lib
LIBS       := -L$(LIBDIR) -ldragon -lm

# Project sources (adjust to match repo)
SRCS       := src/main.c src/hud.c src/dungeon.c src/combat.c src/audio.c
OBJS       := $(SRCS:.c=.o)

# Outputs
TARGET_ELF := shattered_realms.elf
TARGET_ROM := shattered_realms.z64
ROMFS      := assets/romfs

# Flags
CFLAGS  := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections $(INCLUDES)
LDFLAGS := -T $(LIBDIR)/n64.ld $(LIBS)

# Default
all: $(TARGET_ROM)

$(TARGET_ELF): $(OBJS)
	@echo "  [LD]  $@"
	$(CC) -o $@ $(OBJS) $(LDFLAGS)

$(TARGET_ROM): $(TARGET_ELF)
	@echo "  [ROM] $@"
	# Build ROM filesystem (must exist, keep a .keep file in git)
	mkdfs $(ROMFS) romfs.dfs
	# Use libdragon's standard header under mips64-elf/lib
	n64tool -l 2M -t "Shattered Realms" -h $(LIBDIR)/header -o $@ $< -s 1M -B romfs.dfs
	chksum64 $@

%.o: %.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	@echo "  [CLEAN]"
	rm -f $(OBJS) $(TARGET_ELF) $(TARGET_ROM) romfs.dfs

.PHONY: all clean
