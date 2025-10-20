#include <libdragon.h>

int main(void) {
    dfs_init(DFS_DEFAULT_LOCATION);
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_RESAMPLE);
    rdpq_init();
    rdpq_set_mode_standard();

    for (;;) {
        surface_t *s = display_get();
        rdpq_attach(s, NULL);
        rdpq_clear(RGBA32(0, 16, 48, 255));  // dark blue
        rdpq_detach_show();
    }
    return 0;
}
