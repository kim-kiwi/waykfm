package game

import rl "vendor:raylib"

world: World
plr: Entity
enemy: Entity

square :: proc(pos, vel, size: vec2, inv_mass: f32) {
    e := entity_create(&world)
    world.positions[e] = pos
    world.velocities[e] = vel
    world.elasticities[e] = 0.0
    world.frictions[e] = 0.5
    world.inv_mass[e] = inv_mass
    world.sizes[e] = size
    world.colors[e] = {255,255,255,255}
}

init :: proc() {
    plr = entity_create(&world)
    world.positions[plr] = {190, 190}
    world.velocities[plr] = {50,0}
    world.elasticities[plr] = 0.5
    world.frictions[plr] = 0.1
    world.inv_mass[plr] = 1.0
    world.sizes[plr] = {50,50}
    world.colors[plr] = {255,255,255,255}
    world.inputs[plr] = true;
    world.prey[plr] = true;
    enemy = entity_create(&world)
    world.positions[enemy] = {-240,-240}
    world.velocities[enemy] = {100,100}
    world.elasticities[enemy] = 0.5
    world.frictions[enemy] = 0.1
    world.inv_mass[enemy] = 1
    world.sizes[enemy] = {50,50}
    world.colors[enemy] = {255,0,0,255}
    world.predator[enemy] = {target=plr};

    square({-250,-250}, {0,0}, {10,500}, 0.0)
    square({-250,-250}, {0,0}, {500,10}, 0.0)
    square({240,-250}, {0,0}, {10,500}, 0.0)
    square({-250,240}, {0,0}, {500,10}, 0.0)
    // square({100,100}, {0,0}, {50,50}, 0.0)
    // square({100,100}, {0,0}, {50,50}, 0.0)
    // square({100,100}, {0,0}, {50,50}, 0.0)
}

loop :: proc() {
    clear_system(&world)
    input_system(&world)
    rigidbody_system(&world)
    collision_system(&world)
    predator_system(&world)
    rl.BeginDrawing()
    rl.ClearBackground({24,24,24,255})
    render_system(&world)
    rl.EndDrawing()
    deletion_system(&world)
}

main :: proc() {
    rl.InitWindow(500,500,"W.A.Y.K.F.M.")
    defer rl.CloseWindow()
    init()
    for !rl.WindowShouldClose() {
        loop()
    }
}
