#include "hitbox.h"
#include "entity.h"

bool hitbox_aabb(Entity_Hitbox *hb1, Entity_Hitbox *hb2)
{
    float wh1 = hb1->w*0.5;
    float hh1 = hb1->h*0.5;
    float wh2 = hb2->w*0.5;
    float hh2 = hb2->h*0.5;
    return (hb1->x-wh1 <= hb2->x+wh2 && hb1->x+wh1 >= hb2->x-wh2 && hb1->y-hh1 <= hb2->y+hh2 && hb1->y+hh1 >= hb2->y-hh2);
}
