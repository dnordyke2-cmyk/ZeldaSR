#include <libdragon.h>
#include <stdio.h>

/*
 * Zelda: Shattered Realms — minimal visible boot (2025 libdragon)
 * - Uses RDPQ and the built-in console overlay
 * - START cycles the background color so you can verify input + rendering
 *
 * NOTE: display_init_console() is REQUIRED so console_render() actually shows up.
 */

int main(void) {
    // ---- Core subsystems ----
    debug_init_isviewer();              // optional IS-Viewer logging (ignored by most emus)
    timer_init();
    dfs_init(DFS_DEFAULT_LOCATION);     // mount ROM filesystem (romfs.dfs) if present

    // ---- Video / RDPQ / Console ----
    display_init(RESOLUTION_320x240,    // resolution
                 DEPTH_16_BPP,          // color depth
                 2,                     // double-buffer
                 GAMMA_NONE,
                 ANTIALIAS_RESAMPLE);

    display_init_console();             // <-- crucial: attaches console overlay to the display
    rdpq_init();

    // ---- Input ----
    joypad_init();

    // ---- Console text ----
    console_init();
    console_clear();
    printf("Zelda: Shattered Realms (alpha engine test)\n");
    printf("Framebuffer + RDPQ + Input OK.\n");
    printf("Press START to cycle background color.\n");

    // Start on a bright color so a visible frame appears immediately
    color_t BG_COLORS[] = {
        RGBA16(0, 0, 0, 1),     // black
        RGBA16(0, 0, 10, 1),    // blue
        RGBA16(0, 10, 0, 1),    // green
        RGBA16(10, 0, 0, 1),    // red
        RGBA16(10,10,0, 1),     // yellow (bright)
    };
    const int BG_COUNT = sizeof(BG_COLORS) / sizeof(BG_COLORS[0]);
    int bg_idx = 4; // start on yellow so you see color immediately

    while (1) {
        // ---- Input ----
        joypad_poll();
        joypad_buttons_t btn = joypad_get_buttons_pressed(JOYPAD_PORT_1);
        if (btn.start) {
            bg_idx = (bg_idx + 1) % BG_COUNT;
        }

        // ---- Render one frame ----
        surface_t *disp = display_get();      // acquire backbuffer
        rdpq_attach_clear(disp, NULL);        // attach RDP to color buffer, clear Z
        rdpq_clear(BG_COLORS[bg_idx]);        // clear color buffer to chosen color
        console_render();                     // draw console text overlay
        rdpq_detach_show();                   // present the frame

        wait_ms(1);                           // slight pacing
    }

    return 0;
}
