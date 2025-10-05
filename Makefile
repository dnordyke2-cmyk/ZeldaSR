# -------------------------------------------------------------
# Zelda: Shattered Realms — Minimal Alpha Build
# Compatible with libdragon 3.x (N64)
# -------------------------------------------------------------

# Toolchain setup
N64_PREFIX := mips64-elf-
CC         := $(N64_PREFIX)gcc
LD         := $(N64_PREFIX)ld
OBJCOPY    := $(N64_PREFIX)objcopy

# Environment paths
N64_INST   ?= /home/runner/.local/libdragon
LIBDRAGON  := $(N64_INST)
INCLUDES   := -I$(LIBDRAGON)/include
LIBS       := -L$(LIBDRAGON)/lib -ldragon -lm

# Project sources
SRCS       := src/main.c src/hud.c src/dungeon.c src/combat.c src/audio.c
OBJS       := $(SRCS:.c=.o)

# Output targets
TARGET_ELF := shattered_realms.elf
TARGET_ROM := shattered_realms.z64
ROMFS      := assets/romfs

# Compiler and linker flags
CFLAGS  := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections $(INCLUDES)
LDFLAGS := -T $(LIBDRAGON)/lib/n64.ld $(LIBS)

# -------------------------------------------------------------
# Rules
#
