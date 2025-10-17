#include <libdragon.h>
#include <stdio.h>

/*
 * Zelda: Shattered Realms — verified RDPQ console version (2025 SDK)
 * Displays text via console, cycles background color using START.
 */

int main(void) {
    // Core initialization
    debug_init_isviewer();
    timer_init();
    dfs_init(DFS_DEFAULT_LOCATION);

    // Display + RDPQ setup
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_RESAMPLE);
    rdpq_init();
    joypad_init();

    // Console setup
    console_init();
    console_clear();
    printf("Zelda: Shattered Realms (alpha engine test)\n");
    printf("Framebuffer + RDPQ + Input OK.\n");
    printf("Press START to cycle background color.\n");

    // Background colors
    color_t BG_COLORS[] = {
        RGBA16(0,0,0,1), RGBA16(0,0,10,1), RGBA16(0,10,0,1),
        RGBA16(10,0,0,1), RGBA16(10,10,0,1),
    };
    const int BG_COUNT = sizeof(BG_COLORS)/sizeof(BG_COLORS[0]);
    int bg_idx = 0;

    // Main loop
    while (1) {
        joypad_poll();
        joypad_buttons_t btn = joypad_get_buttons_pressed(JOYPAD_PORT_1);
        if (btn.start)
            bg_idx = (bg_idx + 1) % BG_COUNT;

        // Draw
        surface_t *disp = display_get();
        rdpq_attach_clear(disp, NULL);
        rdpq_clear(BG_COLORS[bg_idx]);
        console_render();     // overlays text on the frame
        rdpq_detach_show();

        wait_ms(1);
    }

    return 0;
}
