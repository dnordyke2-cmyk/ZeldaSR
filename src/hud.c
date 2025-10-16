#include <libdragon.h>
#include <stdio.h>
#include "hud.h"

/* Minimal placeholder HUD state */
static int s_hearts = 3;
static int s_rupees = 0;

void hud_init(void) {
    /* Using the built-in 8x8 system font via graphics_*.
     * No explicit font load needed for the basic text helpers. */
}

void hud_draw(surface_t *fb) {
    char buf[64];

    /* Set draw color: white text, transparent bg */
    graphics_set_color(RGBA32(255,255,255,255), 0);

    /* Example: hearts (HP) at top-left */
    snprintf(buf, sizeof(buf), "HP: %d", s_hearts);
    graphics_draw_text(fb, 8, 8, buf);

    /* Example: rupees at top-right (simple right edge offset) */
    snprintf(buf, sizeof(buf), "R: %d", s_rupees);
    graphics_draw_text(fb, 280, 8, buf);

    /* You can expand here with icons, meters, etc. */
}
