#include <libdragon.h>
#include <stdio.h>

/*
 * Shattered Realms — minimal engine bring-up (current libdragon trunk)
 * Initializes video + RDPQ, displays text overlay, and cycles colors with START.
 */

int main(void) {
    // ---- Core subsystems ----
    debug_init_isviewer();
    timer_init();
    dfs_init(DFS_DEFAULT_LOCATION);

    // ---- Video / RDPQ ----
    display_init(
        RESOLUTION_320x240,
        DEPTH_16_BPP,
        2,
        GAMMA_NONE,
        ANTIALIAS_RESAMPLE
    );
    rdpq_init();

    // ---- Input ----
    joypad_init();

    // ---- Text console ----
    console_init();
    console_clear();
    printf("Zelda: Shattered Realms (alpha engine test)\n");
    printf("Build OK: framebuffer + input online.\n");
    printf("Press START to cycle background color.\n");

    color_t BG_COLORS[] = {
        RGBA16(0, 0, 0, 1),     // black
        RGBA16(0, 0, 10, 1),    // blue
        RGBA16(0, 10, 0, 1),    // green
        RGBA16(10, 0, 0, 1),    // red
        RGBA16(10,10,0, 1),     // yellow
    };
    const int BG_COUNT = sizeof(BG_COLORS) / sizeof(BG_COLORS[0]);
    int bg_idx = 0;

    while (1) {
        // ---- Input ----
        joypad_poll();
        joypad_buttons_t btn = joypad_get_buttons_pressed(JOYPAD_PORT_1);
        if (btn.start) {
            bg_idx = (bg_idx + 1) % BG_COUNT;
        }

        // ---- Render ----
        surface_t *disp = display_get();
        rdpq_attach_clear(disp, NULL);           // attach + clear Z
        rdpq_clear_color(BG_COLORS[bg_idx]);     // set clear color
        rdpq_clear();                            // clear color buffer
        rdpq_detach_show();                      // present frame

        console_render();
        wait_ms(1);
    }

    return 0;
}
