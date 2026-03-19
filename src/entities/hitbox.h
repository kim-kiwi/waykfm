#ifndef ENTITY_HITBOX_H
#define ENTITY_HITBOX_H

#include <raylib.h>
#include "entity.h"

int hitbox_draw(Entity_Hitbox *hb);
bool hitbox_aabb(Entity_Hitbox *hb1, Entity_Hitbox *hb2);

#endif // ENTITY_HITBOX_H
