#ifndef GAME_H
#define GAME_H
#include <raylib.h>

int game_init(Camera2D *cam, RenderTexture2D *_object_texture, RenderTexture2D *_glow_texture, RenderTexture2D *_gui_texture);
int game_loop(float dt);

#endif // GAME_H
