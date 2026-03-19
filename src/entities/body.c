#include "body.h"
#include <stdio.h>
#include <raylib.h>
#include <math.h>
#include "../global.h"
#include "../utils.h"

int body_handle(Entity *entity, void *user_data, float dt)
{
    // movement
    entity->body.x+=entity->body.dx*dt;
    entity->body.y+=entity->body.dy*dt;
    entity->body.dx*=powf(entity->body.friction,dt);
    entity->body.dy*=powf(entity->body.friction,dt);
    // collide
    const float wh = entity->body.w*0.5;
    const float hh = entity->body.h*0.5;
    if (entity->body.x+wh>BOX_W_H || entity->body.x-wh<-BOX_W_H) {
        entity->body.x=SIGN(entity->body.x)*(BOX_W_H-wh);
        entity->body.dx*=-entity->body.elasticity;
        if (entity->body.on_wall_collide) entity->body.on_wall_collide(entity);
    }
    if (entity->body.y+hh>BOX_H_H || entity->body.y-hh<-BOX_H_H) {
        entity->body.y=SIGN(entity->body.y)*(BOX_H_H-hh);
        entity->body.dy*=-entity->body.elasticity;
        if (entity->body.on_wall_collide) entity->body.on_wall_collide(entity);
    }
    if (entity->body.handle) entity->body.handle(entity,user_data);
    return 0;
}

int body_draw(Entity_Body *body, Color color) // TODO: align coordinate to center
{
    DrawRectangle((int)body->x+center_x-body->w*0.5,(int)body->y+center_y-body->h*0.5, body->w, body->h, color);
    // DrawRectangleLinesEx((Rectangle){(int)body->x+center_x-body->w*0.5,(int)body->y+center_y-body->h*0.5, body->w, body->h},10, BLACK);
    return 0;
}
