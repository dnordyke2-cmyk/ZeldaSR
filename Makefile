TARGET := shattered_realms
OBJS := src/main.o src/hud.o src/dungeon.o src/combat.o src/audio.o

CC := mips-n64-gcc
LD := mips-n64-ld
CFLAGS := -std=gnu11 -O2 -G0 -Wall -Wextra
LDFLAGS := -ldragon -lm

ROMFS_DIR := assets/romfs
ROMFS_IMG := romfs.dfs
ROMFS_FILES := $(shell find $(ROMFS_DIR) -type f 2>/dev/null)

$(ROMFS_IMG): $(ROMFS_FILES)
	mkdfs $@ $(ROMFS_DIR)

all: $(TARGET).z64

$(TARGET).elf: $(OBJS)
	$(CC) -o $@ $^ $(LDFLAGS)

$(TARGET).z64: $(TARGET).elf $(ROMFS_IMG)
	n64tool -l 2M -o $@ -t "SHATTERED REALMS" \
	  -h /usr/mips64-elf/lib/bootcode.bin \
	  $(TARGET).elf -r $(ROMFS_IMG)
	chksum64 $@

clean:
	rm -f $(OBJS) $(TARGET).elf $(TARGET).z64 $(ROMFS_IMG)

src/%.o: src/%.c
	$(CC) $(CFLAGS) -c -o $@ $<
clean:
	rm -f $(OBJS) $(TARGET).elf $(TARGET).z64 $(ROMFS_IMG)
