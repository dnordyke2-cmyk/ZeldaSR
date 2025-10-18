# ===============================
# Zelda: Shattered Realms Makefile
# Libdragon 2025 verified version
# ===============================

N64_INST ?= /opt/libdragon
MIPS_PREFIX ?= mips64-elf
CC := $(MIPS_PREFIX)-gcc
AR := $(MIPS_PREFIX)-ar

TITLE    := Shattered Realms
ROM      := shattered_realms.z64
ELF      := shattered_realms.elf
ROMSIZE  := 2M
SRC_DIR  := src
ASSETS_DIR := assets/romfs
DFS := romfs.dfs

SRCS := $(wildcard $(SRC_DIR)/*.c)
OBJS := $(SRCS:.c=.o)

# --- Libdragon paths ---
DRAGON_INC := $(N64_INST)/mips64-elf/include
DRAGON_LIB := $(N64_INST)/mips64-elf/lib
N64_LD     := $(DRAGON_LIB)/n64.ld

# --- Fail fast if missing ---
ifeq ($(wildcard $(DRAGON_INC)/libdragon.h),)
$(error libdragon headers not found at $(DRAGON_INC))
endif
ifeq ($(wildcard $(N64_LD)),)
$(error n64.ld not found in $(DRAGON_LIB))
endif

# --- IPL3 header required ---
HEADER_FILE := $(firstword $(wildcard \
  $(N64_INST)/lib/header \
  $(N64_INST)/lib/ipl3.bin \
  $(N64_INST)/lib/ipl3_6102.bin \
  $(N64_INST)/mips64-elf/lib/header))
ifeq ($(HEADER_FILE),)
$(error Missing IPL3 header. Run libdragon ./build.sh so that $(N64_INST)/lib/header exists.)
else
$(info [INFO] Using IPL3 header: $(HEADER_FILE))
HEADER_OPT := -h $(HEADER_FILE)
endif

CFLAGS  := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections -I$(DRAGON_INC)
LDFLAGS := -T $(N64_LD) -L$(DRAGON_LIB) -ldragon -lc -lm -ldragonsys -Wl,--gc-sections

.PHONY: all clean distclean fixcrc showpaths

all: $(ROM)

showpaths:
	@echo "INC=$(DRAGON_INC)"
	@echo "LIB=$(DRAGON_LIB)"
	@echo "LD=$(N64_LD)"
	@echo "HEADER=$(HEADER_FILE)"

$(SRC_DIR)/%.o: $(SRC_DIR)/%.c
	@echo "  [CC]  $<"
	$(CC) $(CFLAGS) -c $< -o $@

$(ELF): $(OBJS
