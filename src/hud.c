#include <libdragon.h>
#include <stdio.h>
#include "hud.h"

/* Minimal placeholder HUD state */
static int s_hearts = 3;
static int s_rupees = 0;

void hud_init(void) {
    /* Using built-in system font with graphics_* API (no explicit load). */
}

void hud_draw(surface_t *fb) {
    char buf[64];

    /* graphics_set_color expects a uint32_t matching the framebuffer format.
     * For 16bpp (RGB555/565), 0xFFFF is white and 0x0000 is transparent/black.
     * (Exact mapping depends on mode, but these work well for simple HUD text.)
     */
    graphics_set_color(0xFFFF, 0x0000);  /* white fg, transparent/black bg */

    /* Hearts (HP) at top-left */
    snprintf(buf, sizeof(buf), "HP: %d", s_hearts);
    graphics_draw_text(fb, 8, 8, buf);

    /* Rupees at top-right (adjust X for your font/spacing as needed) */
    snprintf(buf, sizeof(buf), "R: %d", s_rupees);
    graphics_draw_text(fb, 280, 8, buf);
}
