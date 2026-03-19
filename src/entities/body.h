#ifndef ENTITY_BODY_H
#define ENTITY_BODY_H
#include <raylib.h>
#include "entity.h"

int body_handle(Entity *body, void *user_data, float dt);
int body_draw(Entity_Body *body, Color color);

#endif
