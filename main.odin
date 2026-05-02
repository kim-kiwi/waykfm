package game

import rl "vendor:raylib"
import "core:fmt"

world: World
plr: Entity
enemy: Entity

init :: proc() {
    plr = spawn_player(&world)
    // fmt.printfln("plr=%d, entity=%d",plr,enemy)
    for _ in 0..<100 {
        enemy = spawn_enemy(&world,plr)
    }

    // enemy = spawn_enemy(&world,0)

    spawn_square(&world, {-250,-250}, {10,500}, {0,0}, 0.0)
    spawn_square(&world, {-250,-250}, {500,10}, {0,0}, 0.0)
    spawn_square(&world, {240,-250}, {10,500}, {0,0}, 0.0)
    spawn_square(&world, {-250,240}, {500,10}, {0,0}, 0.0)
}

restart :: proc() {
    clear(&world.collision_events)
    clear(&world.deletion_events)
    clear(&world.spawn_events)
    entity_delete(&world,plr)
    for e in world.predators {
        entity_delete(&world,e)
    }
    plr = spawn_player(&world)
    for _ in 0..<100 {
        enemy = spawn_enemy(&world,plr)
    }
    world.gameover=false
    world.should_restart=false
}

loop :: proc() {
    clear_system(&world)
    input_system(&world)

    // debug_system(&world)
    overlap_resolution_system(&world)
    rigidbody_system(&world)
    collision_resolution_system(&world)

    predator_system(&world)
    gameover_system(&world)

    rl.BeginDrawing()
    rl.ClearBackground({24,24,24,255})
    render_system(&world)
    rl.DrawFPS(0,0)
    rl.EndDrawing()

    deletion_system(&world)
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
