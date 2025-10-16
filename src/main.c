#include <libdragon.h>
#include "hud.h"

/*
 * Minimal boot loop for current libdragon (rdpq_attach takes 2 params).
 * We attach the color framebuffer and pass NULL for the Z-buffer since
 * the early alpha doesn't need depth yet.
 */

int main(void) {
    /* Video + RDPQ init (double-buffer, 320x240, 16bpp) */
    display_init( RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_RESAMPLE );
    rdpq_init();

    /* Optional: copy mode is fine for simple 2D/HUD */
    rdpq_set_mode_copy(false);

    while (1) {
        surface_t *fb = display_get();

        /* Attach framebuffer; no Z-buffer for now */
        rdpq_attach(fb, NULL);

        /* Clear the screen (black) */
        rdpq_clear(RGBA32(0,0,0,255));

        /* Draw HUD (update to your actual HUD draw if needed) */
        hud_draw();

        /* Present */
        rdpq_detach_show();
    }

    return 0;
}
