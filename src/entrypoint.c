// src/entrypoint.c
#include <libdragon.h>

void run_boot_screen(void) {
    // Use display_get (display_lock is deprecated in recent libdragon)
    surface_t *disp = display_get();
    if (!disp) return;

    // Dark blue background + white text
    graphics_fill_screen(disp, graphics_make_color(0, 16, 48, 255));
    graphics_set_color(graphics_make_color(255,255,255,255), 0);
    graphics_draw_text(disp, 16, 16, "Shattered Realms — boot OK");

    display_show(disp);
}
