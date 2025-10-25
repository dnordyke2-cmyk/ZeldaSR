#include <libdragon.h>
#include <stdio.h>

int main(void) {
    /* Init video and a double-buffered display */
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, ANTIALIAS_NONE);

    /* Init console and route printf() to the on-screen console */
    console_init();
    console_set_debug(true);

    /* Optional: init the modern input API (only needed if you read input) */
    // joypad_init();

    printf("Shattered Realms booted!\n");
    printf("Libdragon console is active. \\o/\n");

    while (1) {
        /* Wait for a free framebuffer */
        display_context_t disp = 0;
        while (!(disp = display_lock())) {
            /* If you prefer non-blocking, use display_try_lock()
               and do something else when it returns 0. */
        }

        /* (Optional) clear the background; 0 = black */
        graphics_fill_screen(disp, 0);

        /* Draw the console contents into this framebuffer */
        console_render(disp);

        /* Present the frame */
        display_show(disp);

        /* Simple throttling to avoid a hot loop (about ~60 fps anyway) */
        wait_ms(16);
    }

    return 0;
}
