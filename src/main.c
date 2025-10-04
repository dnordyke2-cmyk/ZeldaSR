#include <libdragon.h>

int main(void) {
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_OFF);
    rdpq_init();

    while (1) {
        surface_t *disp = display_get();
        rdpq_attach(disp);
        rdpq_clear(0x101018FF); // dark gray screen
        rdpq_detach_show();
    }
    return 0;
}
