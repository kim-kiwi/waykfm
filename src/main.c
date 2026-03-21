#include <stdio.h>
#include <raylib.h>
#include "game.h"
#include "utils.h"

// 0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216
// 0.32465246735834974, 0.27803730045319414, 0.23574607655586352, 0.19789869908361468, 0.16447445657715493, 0.1353352832366127, 0.11025052530448523, 0.08892161745938636, 0.07100535373963698, 0.05613476283413374
const char *blurShaderCode =
"#version 330 core\n"
"\n"
"uniform sampler2D texture0;\n"
"uniform float weight[5] = float[](0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);\n"
"\n"
"uniform vec2 direction;\n"
"uniform float glowIntensity;\n"
"\n"
"in vec2 fragTexCoord;\n"
"\n"
"out vec4 FragColor;\n"
"\n"
"void main() {\n"
"    vec3 result = texture(texture0, fragTexCoord).rgb * weight[0];\n"
"\n"
"    for (int i = 1; i < 5; i++) {\n"
"        vec2 offset = direction * float(i);\n"
"        result += texture(texture0, fragTexCoord + offset).rgb * weight[i];\n"
"        result += texture(texture0, fragTexCoord - offset).rgb * weight[i];\n"
"    }\n"
"\n"
"    FragColor = vec4(result*glowIntensity, 1.0);\n"
"}\n";
const char *brightPassShaderCode =
"#version 330\n"
"in vec2 fragTexCoord;\n"
"out vec4 fragColor;\n"
"\n"
"uniform sampler2D texture0;\n"
"\n"
"void main() {\n"
"    vec4 color = texture(texture0, fragTexCoord);\n"
"    float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));\n"
"    fragColor=brightness > 0.0 ? color : vec4(0);\n"
"}\n";


#define INIT_WIDTH 500
#define INIT_HEIGHT 500
int center_x = INIT_WIDTH/2;
int center_y = INIT_HEIGHT/2;

#define DOWNSCALE 4

Shader bright_pass;
Shader blur;

RenderTexture2D target;
RenderTexture2D glow;
RenderTexture2D gui;
RenderTexture2D tmpA;
RenderTexture2D tmpB;
RenderTexture2D blurred;

int glowLoc;
int dirLoc;

void blurrify(RenderTexture2D *ttt, float gi)
{
        BeginTextureMode(tmpA);
            ClearBackground(BLANK);
            BeginShaderMode(bright_pass);
                DrawTexturePro(
                    ttt->texture,
                    (Rectangle) {0, 0, ttt->texture.width, -ttt->texture.height},
                    (Rectangle) {0, 0, tmpA.texture.width, tmpA.texture.height},
                    (Vector2) {0},
                    0,
                    WHITE
                );
            EndShaderMode();
        EndTextureMode();

        for (size_t i = 0; i < 5; i++) {
            BeginTextureMode(tmpB);
                ClearBackground(BLANK);
                BeginShaderMode(blur);
                    float glowIntensity = gi;
                    SetShaderValue(blur, glowLoc, &glowIntensity, SHADER_UNIFORM_FLOAT);
                    SetShaderValue(blur, dirLoc, &(Vector2) {1.0 / tmpB.texture.width, 0}, SHADER_UNIFORM_VEC2);
                    DrawTexturePro(
                        tmpA.texture,
                        (Rectangle) {0, 0, tmpA.texture.width, -tmpA.texture.height},
                        (Rectangle) {0, 0, tmpB.texture.width, tmpB.texture.height},
                        (Vector2) {0},
                        0,
                        WHITE
                    );
                EndShaderMode();
            EndTextureMode();

            BeginTextureMode(tmpA);
                ClearBackground(BLANK);
                BeginShaderMode(blur);
                    glowIntensity=gi;
                    SetShaderValue(blur, glowLoc, &glowIntensity, SHADER_UNIFORM_FLOAT);
                    SetShaderValue(blur, dirLoc, &(Vector2) {0, 1.0 / tmpA.texture.height}, SHADER_UNIFORM_VEC2);
                    DrawTexturePro(
                        tmpB.texture,
                        (Rectangle) {0, 0, tmpB.texture.width, -tmpB.texture.height},
                        (Rectangle) {0, 0, tmpA.texture.width, tmpA.texture.height},
                        (Vector2) {0},
                        0,
                        WHITE
                    );
                EndShaderMode();
            EndTextureMode();
        }
        // BeginTextureMode(*ttt);
        //     ClearBackground(BLANK);
        //     DrawTexturePro(
        //         tmpA.texture,
        //         (Rectangle) {0, 0, tmpA.texture.width, -tmpA.texture.height},
        //         (Rectangle) {0, 0, ttt->texture.width, ttt->texture.height},
        //         (Vector2) {0},
        //         0,
        //         WHITE
        //     );
        // EndTextureMode();
}

int main()
{
    SetConfigFlags(FLAG_WINDOW_RESIZABLE | FLAG_WINDOW_MAXIMIZED);
    InitWindow(INIT_WIDTH,INIT_HEIGHT,"Game");
    MaximizeWindow();
    Camera2D camera = { 0 };
    camera.target = (Vector2){ 0,0 };
    camera.offset = (Vector2){ 0,0 };
    camera.rotation = 0.0f;
    camera.zoom = 1.0f;

    // SetExitKey(KEY_NULL);
    // SetTargetFPS(60);

    bright_pass = LoadShaderFromMemory(0,brightPassShaderCode);
    blur = LoadShaderFromMemory(0,blurShaderCode);

    target = LoadRenderTexture(INIT_WIDTH, INIT_HEIGHT);
    glow = LoadRenderTexture(INIT_WIDTH, INIT_HEIGHT);
    gui = LoadRenderTexture(INIT_WIDTH, INIT_HEIGHT);
    tmpA = LoadRenderTexture(INIT_WIDTH/DOWNSCALE, INIT_HEIGHT/DOWNSCALE);
    tmpB = LoadRenderTexture(INIT_WIDTH/DOWNSCALE, INIT_HEIGHT/DOWNSCALE);
    blurred = LoadRenderTexture(INIT_WIDTH, INIT_HEIGHT);

    glowLoc = GetShaderLocation(blur, "glowIntensity");
    dirLoc = GetShaderLocation(blur, "direction");

    // BeginTextureMode(tmpA);
    //     BeginShaderMode(blur);
    //         DrawRectangle(0,0,1,1,WHITE);
    //     EndShaderMode();
    //     BeginShaderMode(bright_pass);
    //         DrawRectangle(0,0,1,1,WHITE);
    //     EndShaderMode();
    // EndTextureMode();
    static float resizeTimer = 0;

    game_init(&camera,&target,&glow,&gui);
    while (!WindowShouldClose()) {
        if (IsWindowResized()) {
            resizeTimer = 0.2;
        }
        if (resizeTimer>0) {
            resizeTimer-=GetFrameTime();

            if (resizeTimer<=0) {
                if (GetScreenWidth() >= 16 && GetScreenHeight() >= 16) {
                    center_x = GetScreenWidth()/2;
                    center_y = GetScreenHeight()/2;
                    UnloadRenderTexture(target);
                    UnloadRenderTexture(glow);
                    UnloadRenderTexture(tmpA);
                    UnloadRenderTexture(tmpB);
                    UnloadRenderTexture(blurred);
                    UnloadRenderTexture(gui);
                    target = LoadRenderTexture(GetScreenWidth(), GetScreenHeight());
                    glow = LoadRenderTexture(GetScreenWidth(), GetScreenHeight());
                    tmpA = LoadRenderTexture(GetScreenWidth()/DOWNSCALE, GetScreenHeight()/DOWNSCALE);
                    tmpB = LoadRenderTexture(GetScreenWidth()/DOWNSCALE, GetScreenHeight()/DOWNSCALE);
                    blurred = LoadRenderTexture(GetScreenWidth(), GetScreenHeight());
                    gui = LoadRenderTexture(GetScreenWidth(), GetScreenHeight());
                }
            }
        }

        if (game_loop(GetFrameTime())) break;

        BeginDrawing();
        ClearBackground(BLACK);
            DrawTexturePro(
                target.texture,
                (Rectangle) {0, 0, target.texture.width, -target.texture.height},
                (Rectangle) {0, 0, target.texture.width, target.texture.height},
                (Vector2) {0},
                0,
                WHITE
            );
            DrawTexturePro(
                glow.texture,
                (Rectangle) {0, 0, glow.texture.width, -glow.texture.height},
                (Rectangle) {0, 0, target.texture.width, target.texture.height},
                (Vector2) {0},
                0,
                WHITE
            );

            BeginBlendMode(BLEND_ADDITIVE);
            blurrify(&target,0.99);
                DrawTexturePro(
                    tmpA.texture,
                    (Rectangle) {0, 0, tmpA.texture.width, -tmpA.texture.height},
                    (Rectangle) {0, 0, target.texture.width, target.texture.height},
                    (Vector2) {0},
                    0,
                    WHITE
                );

            blurrify(&glow,1.2);
                DrawTexturePro(
                    tmpA.texture,
                    (Rectangle) {0, 0, tmpA.texture.width, -tmpA.texture.height},
                    (Rectangle) {0, 0, target.texture.width, target.texture.height},
                    (Vector2) {0},
                    0,
                    WHITE
                );
            EndBlendMode();

            DrawTexturePro(
                gui.texture,
                (Rectangle) {0, 0, gui.texture.width, -gui.texture.height},
                (Rectangle) {0, 0, target.texture.width, target.texture.height},
                (Vector2) {0},
                0,
                WHITE
            );
        EndDrawing();
    }
    CloseWindow();
    return 0;
}
