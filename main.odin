package game

import rl "vendor:raylib"
import "core:fmt"

world: World
WALL_WIDTH :: 10

init :: proc() {
    plr := spawn_player(&world)
    spawn_enemy(&world,plr)

    spawn_square(&world, {-250-WALL_WIDTH,-250}, {WALL_WIDTH,500}, {0,0}, 0.0)
    spawn_square(&world, {-250-WALL_WIDTH,-250-WALL_WIDTH}, {500+WALL_WIDTH*2,WALL_WIDTH}, {0,0}, 0.0)
    spawn_square(&world, {250,-250}, {WALL_WIDTH,500}, {0,0}, 0.0)
    spawn_square(&world, {-250-WALL_WIDTH,250}, {500+WALL_WIDTH*2,WALL_WIDTH}, {0,0}, 0.0)

    spawn_coin(&world, {cast(f32)rl.GetRandomValue(-250,250),cast(f32)rl.GetRandomValue(-250,250)})
}

restart :: proc() {
    clear_system(&world)
    // for e in world.playables do entity_delete(&world,e)
    // for e in world.predators do entity_delete(&world,e)
    for e in world.entities do entity_delete(&world, e)

    plr := spawn_player(&world)
    spawn_enemy(&world,plr)
    world.gameover=false
    world.should_restart=false
    world.point=0

    spawn_square(&world, {-250-WALL_WIDTH,-250}, {WALL_WIDTH,500}, {0,0}, 0.0)
    spawn_square(&world, {-250-WALL_WIDTH,-250-WALL_WIDTH}, {500+WALL_WIDTH*2,WALL_WIDTH}, {0,0}, 0.0)
    spawn_square(&world, {250,-250}, {WALL_WIDTH,500}, {0,0}, 0.0)
    spawn_square(&world, {-250-WALL_WIDTH,250}, {500+WALL_WIDTH*2,WALL_WIDTH}, {0,0}, 0.0)

    spawn_coin(&world, {cast(f32)rl.GetRandomValue(-250,250),cast(f32)rl.GetRandomValue(-250,250)})
}

loop :: proc() {
    clear_system(&world)
    input_system(&world)

    overlap_resolution_system(&world)
    // debug_system(&world)
    rigidbody_system(&world)
    collision_resolution_system(&world)

    lifetime_system(&world)
    area_system(&world)

    point_system(&world)
    predator_system(&world)
    gameover_system(&world)

    rl.BeginDrawing()
    rl.ClearBackground({24,24,24,255})
    render_system(&world)
    rl.DrawFPS(0,0)
    rl.EndDrawing()

    deletion_system(&world)
    spawn_system(&world)
    if world.should_restart do restart()

}

main :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(500,500,"W.A.Y.K.F.M.")
    rl.MaximizeWindow()
    // rl.SetTargetFPS(10)
    defer rl.CloseWindow()
    init()
    for !rl.WindowShouldClose() {
        loop()
    }
}
