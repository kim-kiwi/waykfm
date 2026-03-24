#include <stdio.h>
#include <raylib.h>
#include <math.h>

static Vector2 normalize_vector(float x, float y)
{
    // float rdist = Q_rsqrt(x*x+y*y);
    float dist = sqrtf(x*x+y*y);
    return dist==0 ? (Vector2){0,0} : (Vector2){x/dist,y/dist};
}

int main()
{
    InitWindow(500,500,"Hello from C");
    Vector2 pos = {0};
    Vector2 vel = {0};
    while (!WindowShouldClose()) {
        float dx=IsKeyDown(KEY_D)-IsKeyDown(KEY_A);
        float dy=IsKeyDown(KEY_S)-IsKeyDown(KEY_W);
        // if (IsKeyDown(KEY_A)) vel.x-=175*GetFrameTime();
        // if (IsKeyDown(KEY_D)) vel.x+=175*GetFrameTime();
        // if (IsKeyDown(KEY_W)) vel.y-=175*GetFrameTime();
        // if (IsKeyDown(KEY_S)) vel.y+=175*GetFrameTime();
        Vector2 direction = normalize_vector(dx,dy);
        vel.x+=direction.x*175*GetFrameTime();
        vel.y+=direction.y*175*GetFrameTime();

        pos.x+=vel.x*GetFrameTime();
        pos.y+=vel.y*GetFrameTime();
        vel.x*=powf(0.8,GetFrameTime());
        vel.y*=powf(0.8,GetFrameTime());

        BeginDrawing();
        ClearBackground(RAYWHITE);
        DrawRectangleV(pos,(Vector2){50,50},BLUE);
        EndDrawing();
    }
    CloseWindow();
    return 0;
}
