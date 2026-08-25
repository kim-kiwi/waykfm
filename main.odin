package game

import rl "vendor:raylib"
import "core:fmt"

world: World
WALL_WIDTH :: 10

init :: proc() {
    world.state = .InGame
    world.plr = spawn_player(&world)
    spawn_enemy(&world,world.plr)

    spawn_square(&world, {-250-WALL_WIDTH,-250}, {WALL_WIDTH,500}, {0,0}, 0.0)
    spawn_square(&world, {-250-WALL_WIDTH,-250-WALL_WIDTH}, {500+WALL_WIDTH*2,WALL_WIDTH}, {0,0}, 0.0)
    spawn_square(&world, {250,-250}, {WALL_WIDTH,500}, {0,0}, 0.0)
    spawn_square(&world, {-250-WALL_WIDTH,250}, {500+WALL_WIDTH*2,WALL_WIDTH}, {0,0}, 0.0)

    spawn_coin(&world, {cast(f32)rl.GetRandomValue(-245,220),cast(f32)rl.GetRandomValue(-245,220)})

    app_path := string(rl.GetApplicationDirectory())
    ability_parser_init()
    skill_parser_init()
    world.abilities=parse_ability_files(app_path)
    world.skills=parse_skill_files(app_path)
}

restart :: proc() {
    force_clear_system(&world)
    // for e in world.playables do entity_delete(&world,e)
    // for e in world.predators do entity_delete(&world,e)
    for e in world.entities do entity_delete(&world, e)

    world.plr = spawn_player(&world)
    spawn_enemy(&world,world.plr)
    world.gameover=false
    world.should_restart=false
    world.point=0

    spawn_square(&world, {-250-WALL_WIDTH,-250}, {WALL_WIDTH,500}, {0,0}, 0.0)
    spawn_square(&world, {-250-WALL_WIDTH,-250-WALL_WIDTH}, {500+WALL_WIDTH*2,WALL_WIDTH}, {0,0}, 0.0)
    spawn_square(&world, {250,-250}, {WALL_WIDTH,500}, {0,0}, 0.0)
    spawn_square(&world, {-250-WALL_WIDTH,250}, {500+WALL_WIDTH*2,WALL_WIDTH}, {0,0}, 0.0)

    spawn_coin(&world, {cast(f32)rl.GetRandomValue(-245,220),cast(f32)rl.GetRandomValue(-245,220)})
}

loop :: proc() {
    version_system()
    if rl.IsKeyPressed(.G) {
        world.state = world.state == .InGame ? .GUI_Ability : .InGame
    }

    if world.state == .InGame {
        gametime_system(&world)
        clear_system(&world)
        playable_system(&world)

        overlap_resolution_system(&world)
        // debug_system(&world)
        rigidbody_system(&world)
        collision_resolution_system(&world)

        lifetime_system(&world)
        area_system(&world)

        point_system(&world)
        powerup_system(&world)
        predator_system(&world)
        gameover_system(&world)
    }

    rl.BeginDrawing()
    rl.ClearBackground({0x18,0x18,0x18,255})
    render_system(&world)
    skill_icon_system(&world)
    if world.state == .GUI_Ability do gui_system(&world)
    rl.DrawFPS(0,0)
    rl.EndDrawing()

    if world.state == .InGame {
        deletion_system(&world)
        spawn_system(&world)
        if world.should_restart do restart()
    }

    state_event_system(&world)
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
