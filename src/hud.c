#include "hud.h"
#include <libdragon.h>

static int player_health = 3;   // 3 hearts
static int player_rupees = 0;   // 0 rupees

void hud_init(void) {
    // Placeholder for sprite setup later
}

void hud_draw(void) {
    // Hearts (top-left)
    for (int i = 0; i < player_health; i++) {
        rdpq_set_prim_color(RGBA32(255,0,0,255));  // red
        rdpq_fill_rectangle(10 + i*20, 10, 25 + i*20, 25);
    }

    // Rupee icon + counter (top-right)
    rdpq_set_prim_color(RGBA32(0,255,0,255));  // green square as rupee
    rdpq_fill_rectangle(270, 10, 285, 25);

    char buf[16];
    sprintf(buf, "%03d", player_rupees);
    graphics_draw_text(290, 10, buf);

    // Item slots (bottom center)
    for (int i = 0; i < 3; i++) {
        rdpq_set_prim_color(RGBA32(255,255,255,255)); // white box
        rdpq_fill_rectangle(50 + i*40, 200, 80 + i*40, 230);
    }
}
