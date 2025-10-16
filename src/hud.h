#ifndef HUD_H
#define HUD_H

#include <libdragon.h>

/* Initialize HUD resources (fonts, state, etc). */
void hud_init(void);

/* Draw the HUD onto the given framebuffer surface. */
void hud_draw(surface_t *fb);

#endif /* HUD_H */
