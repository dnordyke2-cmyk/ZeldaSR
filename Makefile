# Libdragon Makefile (v8): discover tools via PATH; never call host 'cc'
N64_INST ?= /opt/libdragon

# Prefer PATH tools; fall back to N64_INST. "override" prevents make's built-ins.
override CC          := $(or $(shell command -v mips64-elf-gcc 2>/dev/null),$(N64_INST)/bin/mips64-elf-gcc)
override N64TOOL     := $(or $(shell command -v n64tool 2>/dev/null),$(N64_INST)/bin/n64tool)
override ELFCOMPRESS := $(or $(shell command -v n64elfcompress 2>/dev/null),$(N64_INST)/bin/n64elfcompress)

# Title can be set by CI: make TITLE="SR MF079 MC030"
TITLE ?= SHAT REALMS

CFLAGS  := -std=gnu11 -O2 -G0 -Wall -Wextra -ffunction-sections -fdata-sections \
           -I$(N64_INST)/mips64-elf/include
LDFLAGS := -T $(N64_INST)/mips64-elf/lib/n64.ld -Wl,--gc-sections -L$(N64_INST)/mips64-elf/lib
LDLIBS  := -ldragon -lc -lm -ldragonsys

SOURCES := src/main.c
OBJECTS := $(SOURCES:.c=.o)
TARGET  := shattered_realms

.PHONY: all clean showpaths
all: $(TARGET).z64

$(TARGET).elf: $(OBJECTS)
	$(CC) -o $@ $^ $(LDFLAGS) $(LDLIBS)

# n64elfcompress: OUT first, then IN
$(TARGET).bin: $(TARGET).elf
	$(ELFCOMPRESS) $@ $<

$(TARGET).z64: $(TARGET).bin
	$(N64TOOL) -l 2M -t "$(TITLE)" -h $(N64_INST)/mips64-elf/lib/header -o $@ $<

clean:
	rm -f $(OBJECTS) $(TARGET).elf $(TARGET).bin $(TARGET).z64

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

showpaths:
	@echo "--- Makefile paths ---"
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
	@echo "----------------------"
