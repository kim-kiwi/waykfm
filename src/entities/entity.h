#ifndef ENTITY_H
#define ENTITY_H

#include <stdint.h>

typedef enum {
    EntityType_BODY,
    EntityType_HITBOX,
} EntityType;

typedef union Entity Entity;
typedef struct Entity_Hitbox Entity_Hitbox;
typedef struct Entity_Body Entity_Body;

struct Entity_Hitbox {
    EntityType type;
    float x,y,w,h,born,die;
    int (*handle)(Entity_Hitbox *hb, float dt);
    void (*draw)(Entity_Hitbox *hb);
};

struct Entity_Body {
    EntityType type;
    float x,y,w,h;
    float dx,dy;
    float elasticity;
    float friction;
    void (*on_wall_collide)(Entity *body);
    void (*handle)(Entity *body, void *data);
};

union Entity {
    EntityType type;
    Entity_Hitbox hitbox;
    Entity_Body body;
};

#endif
