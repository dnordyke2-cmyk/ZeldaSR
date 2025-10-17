#include <libdragon.h>
#include <stdio.h>

/*
 * Zelda: Shattered Realms — framebuffer bring-up (stable libdragon SDK)
 * Compatible with graphics_* API using uint32_t colors.
 * Renders text + background color cycles using START button.
 */

int main(void) {
    // ---- Core subsystems ----
    debug_init_isviewer();
    timer_init();
    dfs_init(DFS_DEFAULT_LOCATION);

    // ---- Video ----
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_RESAMPLE);

    // ---- Input ----
    controller_init();

    // ---- Graphics ----
    graphics_init();

    // ---- Background colors (uint32_t, 0xRRGGBB) ----
    uint32_t BG_COLORS[] = {
        graphics_make_color(0, 0, 0, 255),       // black
        graphics_make_color(0, 0, 128, 255),     // blue
        graphics_make_color(0, 128, 0, 255),     // green
        graphics_make_color(128, 0, 0, 255),     // red
        graphics_make_color(255, 255, 0, 255),   // yellow
    };
    const int BG_COUNT = sizeof(BG_COLORS) / sizeof(BG_COLORS[0]);
    int bg_idx = 0;

    while (1) {
        // ---- Input ----
        controller_scan();
        struct controller_data keys = get_keys_down();
        if (keys.c[0].start)
            bg_idx = (bg_idx + 1) % BG_COUNT;

        // ---- Draw frame ----
        surface_t *disp = display_get();

        // Fill screen background
        graphics_fill_screen(disp, BG_COLORS[bg_idx]);

        // Set text colors (white on transparent)
        graphics_set_color(graphics_make_color(255,255,255,255), 0);
        graphics_draw_text(disp, 16, 16, "Zelda: Shattered Realms (alpha engine test)");
        graphics_draw_text(disp, 16, 32, "Build OK: framebuffer + input online.");
        graphics_draw_text(disp, 16, 48, "Press START to cycle background color.");

        // Show frame
        display_show(disp);

        // Limit loop speed slightly
        wait_ms(1);
    }

    return 0;
}
