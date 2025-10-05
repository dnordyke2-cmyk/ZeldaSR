#include <libdragon.h>
#include "hud.h"

int main(void) {
    // Init display + console + RDP
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_OFF);
    rdpq_init();
    console_init();

    hud_init();

    while (1) {
        surface_t *disp = display_get();
        rdpq_attach(disp);

        // Background
        rdpq_clear(RGBA32(32,32,32,255));

        // HUD overlay
        hud_draw();

        rdpq_detach_show();
    }
    return 0;
}
