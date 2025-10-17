#include <libdragon.h>
#include <stdio.h>

/*
 * Zelda: Shattered Realms — framebuffer bring-up (no RDPQ)
 * - Initializes display (320x240, 16bpp, double-buffer)
 * - Uses graphics_* CPU renderer to draw text & fill background
 * - START cycles background colors to prove input + drawing
 *
 * This avoids RDPQ so it renders on the widest range of emulator cores.
 */

int main(void) {
    // Core subsystems
    debug_init_isviewer();
    timer_init();
    dfs_init(DFS_DEFAULT_LOCATION);

    // Video: 320x240 @ 16bpp, double buffering
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_RESAMPLE);

    // Input (modern API)
    joypad_init();

    // Init graphics 2D CPU rasterizer
    graphics_init();

    // Prepare a few simple colors
    color_t BG_COLORS[] = {
        RGBA16(0, 0, 0, 1),     // black
        RGBA16(0, 0, 10, 1),    // blue
        RGBA16(0, 10, 0, 1),    // green
        RGBA16(10, 0, 0, 1),    // red
        RGBA16(10,10,0, 1),     // yellow
    };
    const int BG_COUNT = sizeof(BG_COLORS)/sizeof(BG_COLORS[0]);
    int bg_idx = 0;

    while (1) {
        // Input
        joypad_poll();
        joypad_buttons_t btn = joypad_get_buttons_pressed(JOYPAD_PORT_1);
        if (btn.start) {
            bg_idx = (bg_idx + 1) % BG_COUNT;
        }

        // Acquire backbuffer
        surface_t *disp = display_get();

        // Fill the whole screen background
        graphics_fill_screen(disp, BG_COLORS[bg_idx]);

        // Draw a simple text overlay
        // Set text color (fg) and background (bg) for subsequent text draws
        graphics_set_color(RGBA16(31,31,31,1), RGBA16(0,0,0,1));  // white on black
        graphics_draw_text(disp, 8, 8,   "Zelda: Shattered Realms (alpha engine test)");
        graphics_draw_text(disp, 8, 24,  "Build OK: framebuffer + input online.");
        graphics_draw_text(disp, 8, 40,  "Press START to cycle background color.");

        // Present
        display_show(disp);

        // Tiny pace so emulators don't spin hot
        wait_ms(1);
    }

    return 0;
}
