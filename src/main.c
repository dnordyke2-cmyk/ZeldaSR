#include <libdragon.h>
#include <stdio.h>

int main(void) {
    /* Video: 320x240, 16bpp, double-buffered */
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_OFF);

    /* Console routed to printf */
    console_init();
    console_set_debug(true);

    debugf("Boot: entering main loop\n");
    printf("Shattered Realms booted!\n");
    printf("If you can read this, the display & console are working.\n");

    while (1) {
        /* Grab a free framebuffer (blocks until one is available) */
        surface_t *disp = display_get();

        /* Clear to black */
        graphics_fill_screen(disp, 0);

        /* Draw console buffer */
        console_render(disp);

        /* Present frame */
        display_show(disp);

        /* ~60 fps pacing */
        wait_ms(16);
    }

    return 0;
}
