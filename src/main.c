// src/main.c
#include <libdragon.h>

int main(void) {
    // Filesystem (for ROMFS), video, and the modern RDPQ pipeline
    dfs_init(DFS_DEFAULT_LOCATION);
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_RESAMPLE);
    rdpq_init();
    rdpq_set_mode_standard();   // sensible defaults

    // Minimal visible loop: clear to dark blue every frame
    for (;;) {
        surface_t *disp = display_get();   // get a framebuffer
        rdpq_attach(disp, NULL);           // bind RDP to it
        rdpq_clear(RGBA32(0, 16, 48, 255));// dark blue
        rdpq_detach_show();                // present
    }
    return 0;
}
