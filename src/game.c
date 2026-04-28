#include "game.h"
#include <stdio.h>
#include <raylib.h>
#include <math.h>
#include <stdbool.h>
#include <string.h>
#include <time.h>
#include <stdlib.h>

#include "global.h"
#include "entities.h"
#include "utils.h"

#define PLR_ELASTICITY 0.1
#define BULL_ELASTICITY 0.1
#define PLR_FRICTION 0.8
#define BULL_FRICTION 0.9

#define da_unordered_remove(list,i) do { \
    typeof(*(list).data) swap = (list).data[i]; \
    (list).data[i] = (list).data[(list).size-1]; \
    (list).data[(list).size-1] = swap; \
    da_pop(list); \
} while(0)

#define da_pop(list) do { \
    if ((list).size>0) (list).size--; \
} while(0)

#define da_clear(list) do { \
    (list).size=0; \
} while(0)

#define da_append(list, value) do { \
    if ((list).size >= (list).cap) { \
        size_t new_cap = (list).cap ? (list).cap*2 : 2; \
        void *new_data=realloc((list).data,sizeof(*(list).data)*new_cap); \
        if (new_data==NULL) { \
            perror("realloc failed"); \
            exit(EXIT_FAILURE); \
        } \
        (list).data=new_data; \
        (list).cap=new_cap; \
    } \
    (list).data[(list).size++]=(value); \
} while(0)

typedef struct {
    const char *title;
    const char *advantages;
    const char *disadvantages;
    void (*do_effect)();
} PowerUp;

typedef enum {
    GameMode_PLAYING,
    GameMode_PAUSED,
    GameMode_GAMEOVER,
    GameMode_GUI,
} GameMode;

typedef struct {
    double trigger_time;
    void *user_data;
    void (*func)(void *data);
} Timer;

typedef struct {
    Timer *data;
    size_t size;
    size_t cap;
} Timer_da;

typedef struct Particle Particle;

struct Particle {
    double born, die;
    float x,y;
    Color color;
    void (*handle)(Particle *p, float dt);
    float dx,dy;
    float size;
    float elasticity;
};

typedef struct {
    Particle *data;
    size_t size;
    size_t cap;
} Particle_da;

typedef struct {
    Entity_Hitbox *data;
    size_t size;
    size_t cap;
} Hitbox_da;

typedef struct {
    Entity *data;
    size_t size;
    size_t cap;
} Entity_da;

typedef struct {
    double *data;
    size_t size;
    size_t cap;
} double_da;

static int do_playing_mode(float dt);
static int do_paused_mode(float dt);
static int do_gameover_mode(float dt);
static int do_gui_mode(float dt);
static void player_control(float dt);
static void bull_track_plr();
static void bull_on_wall_collide(Entity *entity);
static void spread_coin();
static void particle_debris_handle(Particle *p, float dt);
static void particle_dust_handle(Particle *p, float dt);
static Vector2 normalize_vector(float x, float y);
static int roll_powerup();
static int parry_hb_handle(Entity_Hitbox *hb, float dt);
static int enemy_laser_hb_handle(Entity_Hitbox *hb, float dt);
static void emit_debris(float x, float y, float vx, float vy, float life, float size, int count, Color color);
static void parry_hb_draw(Entity_Hitbox *hb);
static void enemy_laser_hb_draw(Entity_Hitbox *hb);
static void bullet_on_wall_collide(Entity *body);

#define PLR_INIT_X 200
#define PLR_INIT_Y 200
Entity plr = {0};
#define BULL_INIT_X -200
#define BULL_INIT_Y -200
Entity bull = {0};

float Q_rsqrt( float number )
{
	long i;
	float x2, y;
	const float threehalfs = 1.5F;

	x2 = number * 0.5F;
	y  = number;
	i  = * ( long * ) &y;                       // evil floating point bit level hacking
	i  = 0x5f3759df - ( i >> 1 );               // what the fuck?
	y  = * ( float * ) &i;
	y  = y * ( threehalfs - ( x2 * y * y ) );   // 1st iteration
//	y  = y * ( threehalfs - ( x2 * y * y ) );   // 2nd iteration, this can be removed

    return y;
}

float bull_dx = 0.0f;
float bull_dy = 0.0f;

int highscore;

bool paused;
bool gameover;
float gameover_wait;
char msg_buf[128];
int score;

int w;
int gameover_w;
int paused_w;
int press_enter_w;
float shaking;
float flash_effect;
float shaking_power;

char filePath[1024];

#define COIN_HALF 25
Entity_Hitbox coin = {
    .w=COIN_HALF*2,.h=COIN_HALF*2
};

int card1;
int card2;
int card3;

Entity_Hitbox *parry_hb = NULL;
Hitbox_da hblist = {0};
Particle_da plist = {0};
Timer_da timerlist = {0};

Entity_da bullet_list = {0};
double_da bullet_die_list = {0};

float sine;

static double playtime = 0.0;

GameMode game_mode=GameMode_PLAYING;

static void powerup_dash(void);
static void powerup_hah(void);
static void powerup_parry(void);
static void powerup_bounce(void);
static void powerup_faster(void);
static void powerup_break(void);
static void powerup_sonic(void);
static void powerup_revolver(void);

PowerUp powerup_list[] = {
    {"Dash[H]","Dash: dash forward","Enemy Size +20%",powerup_dash},
    {"Parry[J]","Parry: parry enemy's attack","Enemy Speed +25%",powerup_parry},
    {"Break[K]","Break: stop instantly","Your Friction -25%\nYour Speed -25%",powerup_break},
    {"Revolver[L]","Revolver: fire six bullets in the reverse of the player's velocity","The bullet can also hit you",powerup_revolver},
    {"Bounce","Your Elasticity +1000%","Enemy Elasticity +500%",powerup_bounce},
    {"Faster!!","Your speed +100%","Enemy Friction -50%",powerup_faster},
    {"Hah?","Size -50%","Your Speed -25%",powerup_hah},
    {"Sonic","Your speed +200%","Enemy blasts laser beam",powerup_sonic},
};

#define POWERUP_LIST_LEN (sizeof(powerup_list)/sizeof(PowerUp))

bool inventory[POWERUP_LIST_LEN] = {0};

#define PLR_SPEED 175
#define BULL_SPEED 250

float plr_speed_mult;
float bull_speed_mult;

float plr_stun;
float bull_stun;

static void use_dash(void *data);
static void use_parry(void *data);
static void use_break(void *data);
static void use_revolver(void *data);

static void use_enemy_laser(void *data);

typedef struct {
    float cooldown;
    void (*use)(void *data);
    KeyboardKey trigger;
} Skill;

typedef enum {
    SKILL_DASH,
    SKILL_PARRY,
    SKILL_BREAK,
    SKILL_REVOLVER,
    SKILL_ENEMY_LASER,
    SKILL_COUNT,
} SkillName;

Skill skill_list[SKILL_COUNT] = {
    [SKILL_DASH] = {
#define SKILL_DASH_COOLDOWN 3.0
        .use=use_dash,
        .trigger=KEY_H,
    },
    [SKILL_PARRY] = {
#define SKILL_PARRY_COOLDOWN 10.0
        .use=use_parry,
        .trigger=KEY_J,
    },
    [SKILL_BREAK] = {
#define SKILL_BREAK_COOLDOWN 1.5
        .use=use_break,
        .trigger=KEY_K,
    },
    [SKILL_REVOLVER] = {
#define SKILL_REVOLVER_COOLDOWN 6.0
        .use=use_revolver,
        .trigger=KEY_L,
    },
    [SKILL_ENEMY_LASER] = {
#define SKILL_ENEMY_LASER_COOLDOWN 5.0
        .use=use_enemy_laser,
    },
};

bool can[SKILL_COUNT] = {0};

bool first_roll;
bool is_fair;

void game_reset()
{
    first_roll = true;
    is_fair = true;
    da_clear(timerlist);
    da_clear(bullet_list);
    da_clear(bullet_die_list);
    da_clear(hblist);
    memset(inventory,0,sizeof(inventory));
    for (int i = 0; i<SKILL_COUNT; ++i) {
        skill_list[i].cooldown=0;
        can[i]=false;
    }
    plr_stun=0;
    bull_stun=0;
    plr_speed_mult=1.0;
    bull_speed_mult=1.0;
    sine=0;
    score=0;
    bull_dx=0;
    bull_dy=0;
    shaking=0;
    shaking_power=0;
    spread_coin();
    bull.body = (Entity_Body){
        .type=EntityType_BODY,
        .w=50, .h=50,
        .x=BULL_INIT_X,.y=BULL_INIT_Y,
        .elasticity = BULL_ELASTICITY,
        .friction = BULL_FRICTION,
        .on_wall_collide = bull_on_wall_collide,
    };
    plr.body = (Entity_Body){
        .type=EntityType_BODY,
        .w=50, .h=50,
        .x=PLR_INIT_X,.y=PLR_INIT_Y,
        .elasticity = PLR_ELASTICITY,
        .friction = PLR_FRICTION,
    };
}

Camera2D *cam;
RenderTexture2D *object_texture;
RenderTexture2D *glow_texture;
RenderTexture2D *gui_texture;
int game_init(Camera2D *_cam, RenderTexture2D *_object_texture, RenderTexture2D *_glow_texture, RenderTexture2D *_gui_texture)
{
    cam=_cam;
    object_texture=_object_texture;
    glow_texture=_glow_texture;
    gui_texture=_gui_texture;

    SetRandomSeed((unsigned int)time(NULL));

    gameover_w = MeasureText("Game Over",40);
    paused_w = MeasureText("Paused",40);
    press_enter_w = MeasureText("Press SPACE to confirm",20);
    game_reset();
    gameover_wait=0;
    gameover=false;
    paused=false;

    bull_track_plr();

    const char *appDir = GetApplicationDirectory();
    strcpy(filePath, appDir);
    strcat(filePath, "score");
    FILE *file = fopen(filePath,"r");
    if (file!=NULL) {
        char buffer[1024];
        size_t bytesRead;

        int a;
        bytesRead = fscanf(file,"%d",&a);
        if (bytesRead == 1) highscore=a;
        fclose(file);
    }

    return 0;
}

static void shake_cam(float duration, float strength)
{
    shaking=duration;
    shaking_power=strength;
}

static int write_highscore()
{
    FILE *file = fopen(filePath,"w");
    if (file!=NULL) {
        fprintf(file,"%d",highscore);
        fclose(file);
    }
    return 0;
}

static int on_gameover()
{
    write_highscore();
    shake_cam(0.5,100.0);
    for (int i = 0; i<50; i++) {
        Vector2 dv = normalize_vector((rand()/(float)RAND_MAX)*2-1,(rand()/(float)RAND_MAX)*2-1);
        float ox = (rand()/(float)RAND_MAX)*2-1;
        float oy = (rand()/(float)RAND_MAX)*2-1;
        da_append(plist,((Particle){
            GetTime(),1.0,
            plr.body.x+ox*20,plr.body.y+oy*20,
            BLUE,
            particle_debris_handle,
            dv.x*1000,dv.y*1000,
            10,
            0.8,
        }));
    }
    return 0;
}

// #define AABB(x1,y1,wh1,hh1,x2,y2,wh2,hh2) (x1-wh1 <= x2+wh2 && x1+wh1 >= x2-wh1 && y1-hh1 <= y2+hh2 && y1+hh1 >= y2-hh2)
#define MAX(x,y) (x>y ? x : y)

int game_loop(float dt)
{
    BeginTextureMode(*glow_texture);
    ClearBackground(BLANK);
    EndTextureMode();
    BeginTextureMode(*gui_texture);
    ClearBackground(BLANK);
    EndTextureMode();

    BeginTextureMode(*object_texture);
    BeginMode2D(*cam);
    ClearBackground(BLACK);
    DrawRectangleLinesEx((Rectangle){center_x-BOX_W_H-2.5,center_y-BOX_H_H-2.5,BOX_W+5,BOX_H+5},5,RAYWHITE);

    cam->offset.y=sinf(M_PI_2*sine*50)*shaking*shaking_power;
    if (shaking<=0) {
        cam->offset.x=0;
        cam->offset.y=0;
    } else {
        sine+=dt;
        shaking-=dt;
        if (sine > 1) sine-=1;
    }

    sprintf(msg_buf,"HIGH SCORE: %d",highscore);
    DrawText(msg_buf, center_x+BOX_W_H+10, center_y-BOX_H_H, 30, GOLD);

    int offset = 50;
    // cooldowns
    if (can[SKILL_DASH]) {
        sprintf(msg_buf,"DASH[H]: %.2fs",MAX(skill_list[SKILL_DASH].cooldown,0));
        DrawText(msg_buf, center_x+BOX_W_H+10, center_y-BOX_H_H+offset, 30, SKYBLUE);
        offset+=50;
    }
    if (can[SKILL_PARRY]) {
        sprintf(msg_buf,"PARRY[J]: %.2fs",MAX(skill_list[SKILL_PARRY].cooldown,0));
        DrawText(msg_buf, center_x+BOX_W_H+10, center_y-BOX_H_H+offset, 30, SKYBLUE);
        offset+=50;
    }
    if (can[SKILL_BREAK]) {
        sprintf(msg_buf,"BREAK[K]: %.2fs",MAX(skill_list[SKILL_BREAK].cooldown,0));
        DrawText(msg_buf, center_x+BOX_W_H+10, center_y-BOX_H_H+offset, 30, SKYBLUE);
        offset+=50;
    }
    if (can[SKILL_REVOLVER]) {
        sprintf(msg_buf,"REVOLVER[L]: %.2fs",MAX(skill_list[SKILL_REVOLVER].cooldown,0));
        DrawText(msg_buf, center_x+BOX_W_H+10, center_y-BOX_H_H+offset, 30, SKYBLUE);
        offset+=50;
    }
    
    // if (can[SKILL_ENEMY_LASER]) {
    //     sprintf(msg_buf,"LASER: %.2fs",MAX(skill_list[SKILL_ENEMY_LASER].cooldown,0));
    //     DrawText(msg_buf, center_x+BOX_W_H+10, center_y-BOX_H_H+offset, 30, MAROON);
    //     offset+=50;
    // }

    // DrawRectangle(+center_x,coin_y+center_y,COIN_HALF,GOLD);
    // drawing thingy
    DrawCircle(coin.x+center_x,coin.y+center_y,COIN_HALF,GOLD);
    // DrawRing((Vector2){coin.x+center_x,coin.y+center_y},COIN_HALF-10,COIN_HALF,0,360,64,BLACK);
    if (game_mode!=GameMode_GAMEOVER) body_draw(&plr.body,BLUE);
    body_draw(&bull.body,RED);

    for (int i = 0; i < bullet_list.size; ++i) {
        Entity *bullet = &bullet_list.data[i];
        body_draw(&bullet->body,GOLD);
    }

    EndMode2D();
    EndTextureMode();
    for (int i = 0; i < hblist.size; ++i) {
        Entity_Hitbox *hb = &hblist.data[i];
        hb->draw(hb);
    }
    BeginTextureMode(*object_texture);
    BeginMode2D(*cam);

    for (int i = plist.size-1; i > -1; --i) {
        Particle *p = &plist.data[i];
        plist.data[i].handle(p,dt);
        if (p->born+p->die < GetTime()) {
            Particle swap = plist.data[i];
            plist.data[i] = plist.data[plist.size-1];
            plist.data[plist.size-1] = swap;
            da_pop(plist);
        }
    }

    DrawFPS(0,0);
    DrawText("v0.1.1", center_x-BOX_W_H, center_y+BOX_H_H+10, 24, RAYWHITE);

    // game logic thingy
    switch (game_mode) {
    case GameMode_PLAYING:
        do_playing_mode(dt);
        break;
    case GameMode_PAUSED:
        do_paused_mode(dt);
        break;
    case GameMode_GAMEOVER:
        do_gameover_mode(dt);
        break;
    case GameMode_GUI:
        // EndTextureMode();
        // BeginTextureMode(*gui_texture);
        do_gui_mode(dt);
        break;
    }
    EndMode2D();
    EndTextureMode();

    BeginTextureMode(*gui_texture);
    if (flash_effect>0) {
        DrawRectangle(0,0,GetScreenWidth(),GetScreenHeight(),Fade(RAYWHITE,flash_effect));
        flash_effect-=dt;
    }
    EndTextureMode();

    return 0;
}

static void bull_track_plr()
{
    float dx = (float)(plr.body.x - bull.body.x);
    float dy = (float)(plr.body.y - bull.body.y);
    float rdist = Q_rsqrt(dx*dx+dy*dy);
    dx*=rdist;
    dy*=rdist;
    bull_dx=dx;
    bull_dy=dy;
}

static Vector2 normalize_vector(float x, float y)
{
    // float rdist = Q_rsqrt(x*x+y*y);
    float dist = sqrtf(x*x+y*y);
    return dist==0 ? (Vector2){0,0} : (Vector2){x/dist,y/dist};
}

static void bull_on_wall_collide(Entity *entity)
{
    float dist = sqrtf(entity->body.x*entity->body.x+entity->body.y*entity->body.y);
    shake_cam(0.2,dist*0.2);
    for (int i = 0; i<20; i++) {
        Vector2 dv = normalize_vector((rand()/(float)RAND_MAX)*2-1,(rand()/(float)RAND_MAX)*2-1);
        // float ox = (rand()/(float)RAND_MAX)*2-1;
        // float oy = (rand()/(float)RAND_MAX)*2-1;
        da_append(plist,((Particle){
            GetTime(),1.0,
            entity->body.x,entity->body.y,
            WHITE,
            particle_debris_handle,
            dv.x*500,dv.y*500,
            5,
            0.2,
        }));
    }
}

static void spread_coin()
{
    coin.x = GetRandomValue(-(BOX_W_H-BOX_PAD),BOX_W_H-BOX_PAD);
    coin.y = GetRandomValue(-(BOX_H_H-BOX_PAD),BOX_H_H-BOX_PAD);
}

static void particle_debris_handle(Particle *p, float dt)
{
    p->x+=p->dx*dt;
    p->y+=p->dy*dt;
    p->dx*=powf(0.1,dt);
    p->dy+=1000*dt;
    p->dy*=powf(0.9,dt);

    if (p->x+p->size>BOX_W_H || p->x-p->size<-BOX_W_H) {
        p->x=SIGN(p->x)*(BOX_W_H-p->size);
        p->dx*=-p->elasticity;
    }
    if (p->y+p->size>BOX_H_H || p->y-p->size<-BOX_H_H) {
        p->y=SIGN(p->y)*(BOX_H_H-p->size);
        p->dy*=-p->elasticity;
    }

    // printf("%lf\n",playtime);
    float radius = (p->born+p->die-GetTime())/p->die*p->size;
    DrawCircle(p->x+center_x,p->y+center_y,radius,p->color);
    // DrawRing((Vector2){p->x+center_x,p->y+center_y},radius*0.5,radius,0,360,64,BLACK);
}

static void particle_dust_handle(Particle *p, float dt)
{
    p->x+=p->dx*dt;
    p->y+=p->dy*dt;

    float radius = (p->born+p->die-GetTime())/p->die*p->size;
    DrawCircle(p->x+center_x,p->y+center_y,radius,p->color);
    // DrawRing((Vector2){p->x+center_x,p->y+center_y},radius*0.5,radius,0,360,64,BLACK);

    // if (p->x+p->size>BOX_W_H || p->x-p->size<-BOX_W_H) {
    //     p->x=SIGN(p->x)*(BOX_W_H-p->size);
    //     p->dx*=-p->elasticity;
    // }
    // if (p->y+p->size>BOX_H_H || p->y-p->size<-BOX_H_H) {
    //     p->y=SIGN(p->y)*(BOX_H_H-p->size);
    //     p->dy*=-p->elasticity;
    // }
}

bool plr_invulnerable;

static int do_playing_mode(float dt)
{
    if (first_roll) {
        first_roll=false;
        if (!roll_powerup()) {
            float dx = (float)(plr.body.x - bull.body.x);
            float dy = (float)(plr.body.y - bull.body.y);
            bull.body.dx=1.0/(1+dx)*-5000;
            bull.body.dy=1.0/(1+dy)*-5000;
            game_mode=GameMode_GUI;
        }
        return 0;
    }

    plr_invulnerable = false;

    playtime+=dt;

    for (int i=bullet_list.size-1; i>-1; --i) {
        Entity *bullet = &bullet_list.data[i];
        body_handle(bullet,&i,dt);
    }

    for (int i=timerlist.size-1; i>-1; --i) {
        Timer *t = &timerlist.data[i];
        if (t->trigger_time<playtime) {
            t->func(t->user_data);
            da_unordered_remove(timerlist,i);
            // Timer swap = timerlist.data[i];
            // timerlist.data[i] = timerlist.data[timerlist.size-1];
            // timerlist.data[timerlist.size-1] = swap;
            // da_pop(timerlist);
        }
    }

    for (int i = hblist.size-1; i > -1; --i) {
        Entity_Hitbox *hb = &hblist.data[i];
        
        if (hb->handle) hb->handle(hb,dt);

        if (playtime-hb->born > hb->die) {
            Entity_Hitbox swap = hblist.data[i];
            hblist.data[i] = hblist.data[hblist.size-1];
            hblist.data[hblist.size-1] = swap;
            da_pop(hblist);
        }
    }

    if (bull_stun<=0 && skill_list[SKILL_ENEMY_LASER].cooldown > 0) skill_list[SKILL_ENEMY_LASER].cooldown-=dt; \
    if (can[SKILL_ENEMY_LASER] && skill_list[SKILL_ENEMY_LASER].cooldown<=0) {
        skill_list[SKILL_ENEMY_LASER].use(NULL);
        skill_list[SKILL_ENEMY_LASER].cooldown=SKILL_ENEMY_LASER_COOLDOWN;
    }

    // gameover
    if (!plr_invulnerable && hitbox_aabb(&plr.hitbox,&bull.hitbox)) {
        game_mode=GameMode_GAMEOVER;
        on_gameover();
        return 1;
    }
    // get coin
    if (hitbox_aabb(&plr.hitbox,&coin)) {
        spread_coin();
        if (++score>highscore && is_fair) highscore=score;
        write_highscore();
        if (score%5==0) {
            if (!roll_powerup()) {
                float dx = (float)(plr.body.x - bull.body.x);
                float dy = (float)(plr.body.y - bull.body.y);
                bull.body.dx=1.0/(1+dx)*-5000;
                bull.body.dy=1.0/(1+dy)*-5000;
                game_mode=GameMode_GUI;
            }
            return 1;
        }
    }

    if (plr_stun>0) plr_stun-=dt;
    else {
        body_handle(&plr,NULL,dt);
        player_control(dt);
    }

    if (bull_stun>0) bull_stun-=dt;
    else {
        bull_track_plr();
        bull.body.dx+=bull_dx*BULL_SPEED*bull_speed_mult*dt;
        bull.body.dy+=bull_dy*BULL_SPEED*bull_speed_mult*dt;
    }
    body_handle(&bull,NULL,dt);

    sprintf(msg_buf,is_fair ? "%d" : "%d [Not Fair]",score);
    w = MeasureText(msg_buf,40);
    DrawText(msg_buf, center_x-w*0.5, center_y-300, 40, RAYWHITE);       // Draw text (using default font)
    return 0;
}

static int do_gameover_mode(float dt)
{
    DrawText("Game Over",center_x-gameover_w*0.5, center_y-300,40,RAYWHITE);
    gameover_wait+=dt;
    if (gameover_wait>1) {
        game_reset();
        game_mode=GameMode_PLAYING;
        gameover_wait=0;
    }
    return 0;
}

static int do_paused_mode(float dt)
{
    DrawText("Paused",center_x-paused_w*0.5, center_y-300,40,RAYWHITE);
    return 0;
}

#define SKILL(skill,...) do { \
    if (skill_list[skill].cooldown > 0) skill_list[skill].cooldown-=dt; \
    if (can[skill] && IsKeyPressed(skill_list[skill].trigger) && skill_list[skill].cooldown<=0) { \
        skill_list[skill].use(__VA_ARGS__); \
        skill_list[skill].cooldown=skill##_COOLDOWN; \
    } \
} while(0)

static void player_control(float dt)
{
    // control
    float dx=IsKeyDown(KEY_D)-IsKeyDown(KEY_A);
    float dy=IsKeyDown(KEY_S)-IsKeyDown(KEY_W);
    Vector2 direction = normalize_vector(dx,dy);

    SKILL(SKILL_DASH,&direction);
    SKILL(SKILL_PARRY,NULL);
    SKILL(SKILL_BREAK,NULL);
    SKILL(SKILL_REVOLVER,&direction);

    plr.body.dx+=direction.x*PLR_SPEED*plr_speed_mult*dt;
    plr.body.dy+=direction.y*PLR_SPEED*plr_speed_mult*dt;

    if (IsKeyPressed(KEY_R)) {
        game_mode=GameMode_GAMEOVER;
        on_gameover();
        return;
    }

    if (IsKeyPressed(KEY_G)) {
        is_fair=false;
        if (!roll_powerup()) {
            float dx = (float)(plr.body.x - bull.body.x);
            float dy = (float)(plr.body.y - bull.body.y);
            bull.body.dx=1.0/(1+dx)*-5000;
            bull.body.dy=1.0/(1+dy)*-5000;
            game_mode=GameMode_GUI;
        }
    }
}

static void gui_card(int x, int y, Vector2 *mouse_pos, int pu_idx, bool selected)
{
    PowerUp *pu = &powerup_list[pu_idx];

    int w = 350;
    float wh = (w/2);
    int h = 400;
    float hh = (h/2);
    
    Color color = BLANK;
    if (selected) {
        color = WHITE;
        if (IsKeyPressed(KEY_SPACE)) {
            pu->do_effect();
            inventory[pu_idx]=true;
            game_mode=GameMode_PLAYING;
        }
    }
    DrawRectangle(x+center_x-wh, y+center_y-hh, w, h, (Color){75,75,175,240});
    DrawRectangleLinesEx((Rectangle){x+center_x-wh, y+center_y-hh, w, h}, 5, color);
    DrawText(pu->title,x+center_x-wh+10,y+center_y-hh+10,30,RAYWHITE);

    int idx = 0;
    char *adv = strdup(pu->advantages);
    char *disadv = strdup(pu->disadvantages);

    char *ptr = strtok(adv,"\n");
    char buf[1024] = {0};
    while (ptr!=NULL) {
        sprintf(buf," + %s",ptr);
        DrawText(buf,x+center_x-wh+10,y+center_y-hh+50+(idx*25),20,LIME);
        ptr = strtok(NULL,"\n");
        idx++;
    }
    ptr = strtok(disadv,"\n");
    while (ptr!=NULL) {
        sprintf(buf," - %s",ptr);
        DrawText(buf,x+center_x-wh+10,y+center_y-hh+50+(idx*25),20,RED);
        ptr = strtok(NULL,"\n");
        idx++;
    }
    free(adv);
    free(disadv);
}

static int roll_powerup()
{
    int powerup_cnt = POWERUP_LIST_LEN;
    for (int i = 0; i<sizeof(inventory)/sizeof(*inventory); i++) {
        if (inventory[i]) powerup_cnt--;
    }
    if (powerup_cnt<3) return 1;

    do {
        card1 = rand()%POWERUP_LIST_LEN;
    } while (inventory[card1]==1);
    
    do {
        card2 = rand()%POWERUP_LIST_LEN;
    } while (card1==card2 || inventory[card2]==1);

    do {
        card3 = rand()%POWERUP_LIST_LEN;
    } while (card1==card3 || card2==card3 || inventory[card3]==1);

    return 0;
}

static int do_gui_mode(float dt)
{
    static int current = 0;
    if (IsKeyPressed(KEY_R)) {
        is_fair=false;
        roll_powerup();
    }
    if (IsKeyPressed(KEY_A) && current > 0) current--;
    if (IsKeyPressed(KEY_D) && current < 2) current++;
    Vector2 mouse_pos = GetMousePosition();
    mouse_pos.x-=center_x;
    mouse_pos.y-=center_y;
    // BeginTextureMode(*gui_texture);
    DrawText("Paused",center_x-paused_w*0.5, center_y-300,40,RAYWHITE);
    gui_card(-375,0,&mouse_pos,card1,current==0);
    gui_card(0,0,&mouse_pos,card2,current==1);
    gui_card(375,0,&mouse_pos,card3,current==2);
    DrawText("Press SPACE to confirm",center_x-press_enter_w*0.5,center_y+BOX_H_H+30,20,RAYWHITE);
    // EndTextureMode();
    return 0;
}

static void powerup_dash(void)
{
    can[SKILL_DASH] = true;
    bull.body.w*=1.25;
    bull.body.h*=1.25;
}
static void powerup_hah(void)
{
    plr.body.w*=0.5;
    plr.body.h*=0.5;
    plr_speed_mult-=0.25;
}
static void powerup_parry(void)
{
    can[SKILL_PARRY] = true;
    bull_speed_mult+=0.25;
}
static void powerup_bounce(void)
{
    plr.body.elasticity+=10*PLR_ELASTICITY;
    bull.body.elasticity+=5*BULL_ELASTICITY;
}
static void powerup_faster(void)
{
    plr_speed_mult+=1.0;
    // bull_speed *= 2.0;
    bull.body.friction *= 1.5;
}
static void powerup_break(void)
{
    can[SKILL_BREAK] = true;
    plr_speed_mult-=0.25;
    plr.body.friction *= 1.25;
}
static void powerup_sonic(void)
{
    can[SKILL_ENEMY_LASER] = true;
    skill_list[SKILL_ENEMY_LASER].cooldown=SKILL_ENEMY_LASER_COOLDOWN;
    plr_speed_mult+=2.0;
}
static void powerup_revolver(void)
{
    can[SKILL_REVOLVER] = true;
}

static void use_dash(void *_data)
{
    Vector2 *dir = _data;
    shake_cam(0.2,50);
    plr.body.dx=0;
    plr.body.dy=0;
    plr.body.x+=dir->x*200;
    plr.body.y+=dir->y*200;
}
static void use_parry(void *_data)
{
    da_append(hblist,((Entity_Hitbox){
        EntityType_HITBOX,
        plr.body.x,plr.body.y,plr.body.w+5,plr.body.h+5,playtime,0.1,
        parry_hb_handle,
        parry_hb_draw,
    }));
    parry_hb=&hblist.data[hblist.size-1];
}

static void use_break(void *_data)
{
    plr.body.dx=0;
    plr.body.dy=0;
    shake_cam(0.2,50);
}

static void use_enemy_laser_delayed(void *_data)
{
    shake_cam(0.5,50);
    emit_debris(bull.body.x,-250,GetRandomValue(500,1000),GetRandomValue(500,1000),1.0,10,50,RED);
    emit_debris(bull.body.x,250,GetRandomValue(500,1000),GetRandomValue(500,1000),1.0,10,50,RED);
    emit_debris(-250,bull.body.y,GetRandomValue(500,1000),GetRandomValue(500,1000),1.0,10,50,RED);
    emit_debris(250,bull.body.y,GetRandomValue(500,1000),GetRandomValue(500,1000),1.0,10,50,RED);

    da_append(hblist,((Entity_Hitbox){
        EntityType_HITBOX,
        bull.body.x,0,bull.body.w,500,playtime,0.75,
        enemy_laser_hb_handle,
        enemy_laser_hb_draw,
    }));
    da_append(hblist,((Entity_Hitbox){
        EntityType_HITBOX,
        0,bull.body.y,500,bull.body.h,playtime,0.75,
        enemy_laser_hb_handle,
        enemy_laser_hb_draw,
    }));
}

static void use_enemy_laser(void *_data)
{
    flash_effect=1.0;
    da_append(timerlist,((Timer){playtime+0.5,NULL,use_enemy_laser_delayed}));
}

static void enemy_laser_hb_draw(Entity_Hitbox *hb)
{
    BeginTextureMode(*glow_texture);
    BeginMode2D(*cam);
    DrawRectangle((int)hb->x+center_x-hb->w*0.5,(int)hb->y+center_y-hb->h*0.5, hb->w, hb->h, Fade(RED,2*(hb->die-(playtime-hb->born))));
    EndMode2D();
    EndTextureMode();
}

static int enemy_laser_hb_handle(Entity_Hitbox *hb, float dt)
{
    if (hitbox_aabb(hb,&plr.hitbox)) {
        game_mode=GameMode_GAMEOVER;
        on_gameover();
    }
    return 0;
}

static void parry_hb_draw(Entity_Hitbox *hb)
{
    BeginTextureMode(*glow_texture);
    BeginMode2D(*cam);
    DrawRectangle((int)hb->x+center_x-hb->w*0.5,(int)hb->y+center_y-hb->h*0.5, hb->w, hb->h, Fade((Color){255,0,255},1.0));
    EndMode2D();
    EndTextureMode();
}

static int parry_hb_handle(Entity_Hitbox *hb, float dt)
{
    plr_invulnerable=true;
    hb->x=plr.body.x;
    hb->y=plr.body.y;
    // parry
    if (hitbox_aabb(hb,&bull.hitbox)) {
        float dx = (float)(plr.body.x - bull.body.x);
        float dy = (float)(plr.body.y - bull.body.y);
        Vector2 dir = normalize_vector(dx,dy);
        bull.body.dx=dir.x*-500;
        bull.body.dy=dir.y*-500;

        shake_cam(0.2,100.0);
        skill_list[SKILL_PARRY].cooldown=0;
        flash_effect=1.0;

        for (int i = 0; i<100; i++) {
            Vector2 dv = normalize_vector((rand()/(float)RAND_MAX)*2-1,(rand()/(float)RAND_MAX)*2-1);
            float ox = (rand()/(float)RAND_MAX)*2-1;
            float oy = (rand()/(float)RAND_MAX)*2-1;
            da_append(plist,((Particle){
                GetTime(),1.0,
                plr.body.x+ox*20,plr.body.y+oy*20,
                (Color){255,0,255,255},
                particle_debris_handle,
                dv.x*GetRandomValue(500,1000),dv.y*GetRandomValue(500,1000),
                5,
                0.2,
            }));
        }
        hb->die=0;
    }
    return 0;
}

static void emit_debris(float x, float y, float vx, float vy, float life, float size, int count, Color color)
{
    for (int i = 0; i<count; i++) {
        Vector2 dv = normalize_vector((rand()/(float)RAND_MAX)*2-1,(rand()/(float)RAND_MAX)*2-1);
        float ox = (rand()/(float)RAND_MAX)*2-1;
        float oy = (rand()/(float)RAND_MAX)*2-1;
        da_append(plist,((Particle){
            GetTime(),life,
            x+ox*20,y+oy*20,
            color,
            particle_debris_handle,
            dv.x*vx,dv.y*vy,
            size,
            0.2,
        }));
    }
}

static void emit_dust(int radius, float x, float y, float size, int count, Color color)
{
    for (int i = 0; i<count; i++) {
        Vector2 dv = normalize_vector((rand()/(float)RAND_MAX)*2-1,(rand()/(float)RAND_MAX)*2-1);
        da_append(plist,((Particle){
            GetTime(),0.1,
            x+dv.x*GetRandomValue(-radius,radius),y+dv.y*GetRandomValue(-radius,radius),
            color,
            particle_dust_handle,
            dv.x*GetRandomValue(-500,500),dv.y*GetRandomValue(-500,500),
            size,
        }));
    }
}

static void bullet_handle(Entity *bullet, void *_data)
{
    int *idx = _data;
    emit_dust(25,bullet->body.x,bullet->body.y,5,10,GOLD);
    if (hitbox_aabb(&bullet->hitbox,&bull.hitbox)) {
        Vector2 swap = {bullet->body.dx, bullet->body.dy};
        bullet->body.dx=bull.body.dx*bullet->body.elasticity;
        bullet->body.dy=bull.body.dy*bullet->body.elasticity;
        bull.body.dx=swap.x*bull.body.elasticity;
        bull.body.dy=swap.y*bull.body.elasticity;
        bull_stun+=1.0;
        emit_debris(bullet->body.x,bullet->body.y,1000,1000,0.2,15,50,RED);
        da_unordered_remove(bullet_list,*idx);
        da_unordered_remove(bullet_die_list,*idx);
        return;
    }
    if (bullet_die_list.data[*idx]<playtime) {
        da_unordered_remove(bullet_list,*idx);
        da_unordered_remove(bullet_die_list,*idx);
    }
}
static void bullet_on_wall_collide(Entity *bullet)
{
    shake_cam(0.2,25);
    emit_debris(bullet->body.x,bullet->body.y,500,500,1.0,5,10,WHITE);
}

static void shot_revolver(void *_data)
{
    shake_cam(0.25,50);
    // (rand()/(float)RAND_MAX)*2-1,(rand()/(float)RAND_MAX)*2-1
    float angle=((rand()/(float)RAND_MAX)-0.5)*PI*0.2;
    float cos_d = cosf(angle);
    float sin_d = sinf(angle);

    Vector2 dv = normalize_vector(-plr.body.dx,-plr.body.dy);
    // Vector2 *dv = _data;

    plr.body.dx+=-dv.x*10;
    plr.body.dy+=-dv.y*10;

    da_append(bullet_die_list,playtime+2.0);
    da_append(bullet_list,((Entity){
        .body = {
            .type=EntityType_BODY,
            .x=plr.body.x,.y=plr.body.y,
            .w=25,.h=25,
            .dx=(dv.x * cos_d - dv.y * sin_d)*PLR_SPEED*plr_speed_mult*2,.dy=(dv.x * sin_d + dv.y * cos_d)*PLR_SPEED*plr_speed_mult*2,
            .elasticity=plr.body.elasticity,
            .friction=plr.body.friction,
            .handle=bullet_handle,
            .on_wall_collide=bullet_on_wall_collide,
        }
    }));
}

static void use_revolver(void *_data)
{
    shake_cam(0.5,50);
    flash_effect=1.0;

    // Vector2 *dv = malloc(sizeof(Vector2));
    // dv->x=((Vector2*)_data)->x;
    // dv->y=((Vector2*)_data)->y;

    // for (float i = 0; i < 5; i+=0.1) {
    //     da_append(timerlist,((Timer){playtime+i,NULL,shot_revolver}));
    // }
    // free(dv);
    // da_append(timerlist,((Timer){playtime+0.7,dv,free}));
    da_append(timerlist,((Timer){playtime+0.1,NULL,shot_revolver}));
    da_append(timerlist,((Timer){playtime+0.2,NULL,shot_revolver}));
    da_append(timerlist,((Timer){playtime+0.3,NULL,shot_revolver}));
    da_append(timerlist,((Timer){playtime+0.4,NULL,shot_revolver}));
    da_append(timerlist,((Timer){playtime+0.5,NULL,shot_revolver}));
    da_append(timerlist,((Timer){playtime+0.6,NULL,shot_revolver}));
}
