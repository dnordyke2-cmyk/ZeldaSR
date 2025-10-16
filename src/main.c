#include <libdragon.h>
#include "hud.h"

/* Minimal CPU-side render loop using graphics_* only (no RDPQ).
 * Uses RGBA32(...) for colors (RGB32 is not defined in current libdragon).
 */
int main(void) {
    /* Initialize display: 320x240, 16bpp, double buffering */
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_RESAMPLE);

    hud_init();

    while (1) {
        /* Acquire framebuffer */
        surface_t *fb = display_get();

        /* Clear screen to opaque black */
        graphics_fill_screen(fb, RGBA32(0, 0, 0, 255));

        /* Draw HUD */
        hud_draw(fb);

        /* Present */
        display_show(fb);
    }

    return 0;
}
