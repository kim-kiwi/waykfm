package game

import "core:slice/heap"

PredatorComp :: struct {
    target: Entity,
}

CollisionEvent :: struct {
    a: Entity,
    b: Entity,
    normal: vec2,
}
SpawnKind :: enum {
    Player,
    Enemy,
    Square,
}
SpawnEvent :: struct {
    kind: SpawnKind,
    pos: vec2,
    size: vec2,
    vel: vec2,
    inv_mass: f32,
    target: Entity,
}
DeletionEvent :: struct {
    entity: Entity,
}
LifeTime :: struct {
    born_at: f64,
    duration: f64,
}

World :: struct {
    next_entity: Entity,
    entities: map[Entity]bool,

    gameover: bool,
    gameover_end_at: f64,
    should_restart: bool,

    positions: map[Entity]vec2,
    velocities: map[Entity]vec2,
    inv_mass: map[Entity]f32,
    frictions: map[Entity]f32,
    elasticities: map[Entity]f32,

    sizes: map[Entity]vec2,
    colors: map[Entity]rgba,
    playables: map[Entity]bool,
    predators: map[Entity]PredatorComp,
    gravities: map[Entity]f32,

    collidables: map[Entity]bool,
    lifetimes: map[Entity]LifeTime,

    collision_events: [dynamic]CollisionEvent,
    spawn_events: [dynamic]SpawnEvent,
    deletion_events: [dynamic]DeletionEvent,
}
