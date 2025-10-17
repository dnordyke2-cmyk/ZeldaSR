#include <libdragon.h>
#include <stdio.h>

/*
 * Zelda: Shattered Realms — compatible RDPQ + console test (for SDKs without display_init_console)
 * Displays text via console, cycles background color using START.
 */

int main(void) {
    // ---- Core subsystems ----
    debug_init_isviewer();
    timer_init();
    dfs_init(DFS_DEFAULT_LOCATION);

    // ---- Video / RDPQ ----
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2,
                 GAMMA_NONE, ANTIALIAS_RESAMPLE);
    rdpq_init();

    // ---- Input ----
    joypad_init();

    // ---- Console overlay ----
    console_init();
    console_clear();
    printf("Zelda: Shattered Realms (alpha engine test)\n");
    printf("Framebuffer + RDPQ + Input OK.\n");
    printf("Press START to cycle background color.\n");

    // ---- Background colors ----
    color_t BG_COLORS[] = {
        RGBA16(0, 0, 0, 1),     // black
        RGBA16(0, 0, 10, 1),    // blue
        RGBA16(0, 10, 0, 1),    // green
        RGBA16(10, 0, 0, 1),    // red
        RGBA16(10,10,0, 1),     // yellow
    };
    const int BG_COUNT = sizeof(BG_COLORS) / sizeof(BG_COLORS[0]);
    int bg_idx = 4;  // start on bright yellow so it’s clearly visible

    while (1) {
        // ---- Input ----
        joypad_poll();
        joypad_buttons_t btn = joypad_get_buttons_pressed(JOYPAD_PORT_1);
        if (btn.start)
            bg_idx = (bg_idx + 1) % BG_COUNT;

        // ---- Render ----
        surface_t *disp = display_get();
        rdpq_attach_clear(disp, NULL);      // attach framebuffer
        rdpq_clear(BG_COLORS[bg_idx]);      // fill background
        console_render();                   // draw text on top
        rdpq_detach_show();                 // present frame

        wait_ms(1);
    }

    return 0;
}
