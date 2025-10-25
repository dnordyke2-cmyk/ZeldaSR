# Minimal, known-good Makefile for libdragon hello app
N64_INST ?= /opt/libdragon

CC         := $(N64_INST)/bin/mips64-elf-gcc
OBJCOPY    := $(N64_INST)/bin/mips64-elf-objcopy
N64TOOL    := $(N64_INST)/bin/n64tool
ELFCOMPRESS:= $(N64_INST)/bin/n64elfcompress

CFLAGS  := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections \
           -I$(N64_INST)/mips64-elf/include
LDFLAGS := -L$(N64_INST)/mips64-elf/lib -ldragon -lm \
           -T $(N64_INST)/mips64-elf/lib/n64.ld -Wl,--gc-sections

SOURCES := src/main.c
OBJECTS := $(SOURCES:.c=.o)
TARGET  := shattered_realms

.PHONY: all clean showpaths

all: $(TARGET).z64

$(TARGET).elf: $(OBJECTS)
	$(CC) -o $@ $^ $(LDFLAGS)

$(TARGET).bin: $(TARGET).elf
	$(ELFCOMPRESS) $< $@

$(TARGET).z64: $(TARGET).bin
	$(N64TOOL) -l 2M -t "SHAT REALMS" -h $(N64_INST)/mips64-elf/lib/header -o $@ $<

clean:
	rm -f $(OBJECTS) $(TARGET).elf $(TARGET).bin $(TARGET).z64

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

showpaths:
	@echo "TOOLCHAIN:"
	@echo "  CC  = $(CC)"
	@echo "TOOLS:"
	@echo "  n64elfcompress = $(ELFCOMPRESS)"
	@echo "  n64tool        = $(N64TOOL)"
	@echo "LIBDRAGON:"
	@echo "  INC     = $(N64_INST)/mips64-elf/include"
	@echo "  LIBDIR  = $(N64_INST)/mips64-elf/lib"
	@echo "  LDSCRIPT= $(N64_INST)/mips64-elf/lib/n64.ld"
	@echo "SOURCES = $(SOURCES)"
