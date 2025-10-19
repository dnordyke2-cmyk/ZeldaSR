// src/main.c
#include <libdragon.h>

int main(void) {
    // Init filesystem (ROMFS), video and a simple text console
    dfs_init(DFS_DEFAULT_LOCATION);
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_RESAMPLE);
    console_init();

    // Simple visible loop so we can verify the ROM actually runs
    for (;;) {
        display_context_t disp = display_lock();
        if (disp) {
            // Dark blue background
            graphics_fill_screen(disp, graphics_make_color(0, 16, 48, 255));
            // White text
            graphics_set_color(graphics_make_color(255,255,255,255), 0);
            graphics_draw_text(disp, 16, 16, "Shattered Realms — boot OK");
            display_show(disp);
        }
    }
    return 0;
}
