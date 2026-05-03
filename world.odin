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
    Coin,
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
Area :: struct {
    min: vec2,
    max: vec2,
    hit: map[Entity]bool,
}
AreaEventKind :: enum { ENTER, EXIT }
AreaEvent :: struct {
    kind: AreaEventKind,
    area: Entity,
    entity: Entity,
}

World :: struct {
    point: i32,

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
    areas: map[Entity]Area,
    points: map[Entity]u8,

    collision_events: [dynamic]CollisionEvent,
    spawn_events: [dynamic]SpawnEvent,
    deletion_events: [dynamic]DeletionEvent,
    area_events: [dynamic]AreaEvent,
}
