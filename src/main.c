// src/main.c
#include <libdragon.h>

int main(void) {
    // Init filesystem (for ROMFS), video, and modern RDPQ
    dfs_init(DFS_DEFAULT_LOCATION);
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_RESAMPLE);
    rdpq_init();
    rdpq_set_mode_standard();

    // Minimal visible loop: solid dark blue each frame
    for (;;) {
        surface_t *s = display_get();
        rdpq_attach(s, NULL);
        rdpq_clear(RGBA32(0, 16, 48, 255));
        rdpq_detach_show();
    }
    return 0;
}
