#include <libdragon.h>
#include <stdio.h>

/*
 * Zelda: Shattered Realms — hard-visibility RDPQ test (2025 SDK)
 * - Bright background clear
 * - Large white rectangle primitive
 * - Console text rendered while attached
 * - START cycles background color
 */

int main(void) {
    // Core init
    debug_init_isviewer();
    timer_init();
    dfs_init(DFS_DEFAULT_LOCATION);

    // Video / RDPQ
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2,
                 GAMMA_NONE, ANTIALIAS_RESAMPLE);
    rdpq_init();

    // Input
    joypad_init();

    // Console overlay
    console_init();
    console_clear();
    printf("Zelda: Shattered Realms (alpha engine test)\n");
    printf("RDPQ attached: clear + rectangle + console.\n");
    printf("Press START to cycle background color.\n");

    // Bright defaults so success is obvious
    color_t BG_COLORS[] = {
        RGBA16(10,10,0,1),   // yellow
        RGBA16(10,0,0,1),    // red
        RGBA16(0,10,0,1),    // green
        RGBA16(0,0,10,1),    // blue
        RGBA16(0,0,0,1),     // black
    };
    const int BG_COUNT = sizeof(BG_COLORS)/sizeof(BG_COLORS[0]);
    int bg_idx = 0;          // start on bright yellow

    while (1) {
        // Input
        joypad_poll();
        joypad_buttons_t btn = joypad_get_buttons_pressed(JOYPAD_PORT_1);
        if (btn.start) bg_idx = (bg_idx + 1) % BG_COUNT;

        // Render
        surface_t *disp = display_get();
        rdpq_attach(disp, NULL);               // attach framebuffer
        rdpq_set_mode_standard();              // standard blender state

        rdpq_clear(BG_COLORS[bg_idx]);         // full-screen clear to bright color

        // Big white rectangle across the top third (x0,y0,x1,y1)
        rdpq_set_prim_color(RGBA16(31,31,31,1));
        rdpq_fill_rectangle(16, 16, 304, 72);

        // Console text while attached (so it actually shows)
        console_render();

        rdpq_detach_show();                    // present

        wait_ms(1);
    }
    return 0;
}
