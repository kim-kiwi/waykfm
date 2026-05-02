package game

spawn_square :: proc(world: ^World, pos, size: vec2, vel: vec2 = {0,0}, inv_mass: f32 = 1.0) -> Entity {
    e := entity_create(world)
    world.positions[e] = pos
    world.velocities[e] = vel
    world.elasticities[e] = 0.0
    world.frictions[e] = 0.5
    world.inv_mass[e] = inv_mass // 0=고정 1=유동
    world.sizes[e] = size
    world.colors[e] = {255,255,255,255}
    return e
}

spawn_player :: proc(world: ^World) -> Entity{
    plr = entity_create(world)
    world.positions[plr] = {95,95}
    world.velocities[plr] = {0,0}
    world.elasticities[plr] = 0.5
    world.frictions[plr] = 0.1
    world.inv_mass[plr] = 1.0/1000.0
    world.sizes[plr] = {50,50}
    world.colors[plr] = {255,255,255,255}
    world.playables[plr] = true
    return plr
}

spawn_enemy :: proc(world: ^World, plr: Entity) -> Entity {
    enemy = entity_create(world)
    // world.positions[enemy] = {-240,-240}
    world.positions[enemy] = {-100,-100}
    world.velocities[enemy] = {100,100}
    world.elasticities[enemy] = 0.5
    world.frictions[enemy] = 0.1
    world.inv_mass[enemy] = 1
    world.sizes[enemy] = {10,10}
    world.colors[enemy] = {255,0,0,255}
    world.predators[enemy] = {target=plr}
    return enemy
}
