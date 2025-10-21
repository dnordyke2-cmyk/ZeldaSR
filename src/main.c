#include <libdragon.h>

int main(void) {
    console_init();
    console_set_debug(true);

    display_init( RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_OFF );
    rdpq_init();
    controller_init();

    console_printf("Shattered Realms booted!\\n");
    while (1) {
        while (display_is_next_draw_buffer_busy());
        surface_t *disp = display_get();
        rdpq_attach(disp, NULL);
        rdpq_set_mode_copy( true );
        rdpq_detach_show();
    }
    return 0;
}
