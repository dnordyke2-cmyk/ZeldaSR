#include <libdragon.h>
#include <stdio.h>

/*
 * Shattered Realms — minimal engine bring-up
 * - Initializes timer, DFS, display, RDPQ, controllers
 * - Renders a solid background color and an on-screen text overlay
 * - START button cycles the background color
 */

int main(void) {
    // ---- Core subsystems ----
    debug_init_isviewer();      // optional: sends logs to IS-Viewer / emulator
    timer_init();               // timers (sleepf, frame pacing if needed)
    dfs_init(DFS_DEFAULT_LOCATION);   // ROM filesystem (romfs.dfs) mount point

    // ---- Video / RDP ----
    // 320x240, 16bpp, double-buffer
    display_init(
        RESOLUTION_320x240,
        DEPTH_16_BPP,
        2,
        GAMMA_NONE,
        ANTIALIAS_RESAMPLE
    );
    rdpq_init();                // modern libdragon RDP interface

    // ---- Input ----
    controller_init();

    // ---- Text console overlay ----
    // The console renders text each frame on top of the current framebuffer.
    console_init();
    console_clear();
    printf("Zelda: Shattered Realms (alpha engine test)\n");
    printf("Build OK: framebuffer + input online.\n");
    printf("Press START to cycle background color.\n");

    // Simple background color cycle (RGBA16 components are 0..31)
    int bg_idx = 0;
    const uint16_t BG_COLORS[] = {
        RGBA16(0, 0, 0, 1),     // black
        RGBA16(0, 0, 10, 1),    // blue-ish
        RGBA16(0, 10, 0, 1),    // green-ish
        RGBA16(10, 0, 0, 1),    // red-ish
        RGBA16(10,10,0, 1),     // yellow-ish
    };
    const int BG_COUNT = sizeof(BG_COLORS) / sizeof(BG_COLORS[0]);

    while (1) {
        // ---- Read input (per-frame) ----
        controller_scan();
        struct controller_data keys = get_keys_down();

        if (keys.c[0].start) {
            bg_idx = (bg_idx + 1) % BG_COUNT;
        }

        // ---- Draw frame ----
        surface_t *disp = display_lock();     // acquire backbuffer
        rdpq_attach(disp, NULL);              // start RDP on this surface
        rdpq_set_mode_standard();             // standard blender/coverage setup
        rdpq_clear_color(BG_COLORS[bg_idx]);  // fill background
        rdpq_detach_show();                   // present to screen

        // Render console overlay text after presenting the frame
        // (console handles locking/show internally)
        console_render();

        // Small pacing tap so emulators don't spin too hot
        // (Optional: remove if you prefer uncapped loop)
        wait_ms(1);
    }

    // Not reached
    return 0;
}
