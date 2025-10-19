// src/main.c
#include <libdragon.h>

int main(void) {
    // Initialize filesystem (DFS), video, and console
    dfs_init(DFS_DEFAULT_LOCATION);
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_RESAMPLE);
    console_init();

    // Visible boot screen so we can verify it runs
    for (;;) {
        display_context_t disp = display_lock();
        if (disp) {
            graphics_fill_screen(disp, graphics_make_color(0, 16, 48, 255)); // dark blue
            graphics_set_color(graphics_make_color(255, 255, 255, 255), 0);
            graphics_draw_text(disp, 16, 16, "Shattered Realms — boot OK");
            display_show(disp);
        }
    }
    return 0;
}
