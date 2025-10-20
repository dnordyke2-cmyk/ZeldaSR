// src/main.c
#include <libdragon.h>

// Implemented in entrypoint.c
void run_boot_screen(void);

int main(void) {
    // Init filesystem (ROMFS), video and simple text console
    dfs_init(DFS_DEFAULT_LOCATION);
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_RESAMPLE);
    console_init();

    // Main loop: draw a visible frame every tick
    for (;;) {
        run_boot_screen();
    }
    return 0;
}
