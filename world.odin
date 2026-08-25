package game

import "core:slice/heap"

PredatorComp :: struct {
    target: Entity,
}
PlayableComp :: struct {
    direction: vec2,
    unlocked_skills: [dynamic]SkillId,
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
    born_at: f32,
    duration: f32,
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

PointEvent :: struct { pt: i32 }

WorldState :: enum {
    InGame,
    GUI_Ability,
}
StateEvent :: struct {
    next: WorldState
}

World :: struct {
    state: WorldState,
    plr: Entity,

    point: i32,
    abilities: []Ability,
    skills: map[SkillId]Skill,
    gametime: f32,

    next_entity: Entity,
    entities: map[Entity]bool,

    gameover: bool,
    gameover_end_at: f32,
    should_restart: bool,

    should_powerup_count: i32,

    positions: map[Entity]vec2,
    velocities: map[Entity]vec2,
    inv_mass: map[Entity]f32,
    frictions: map[Entity]f32,
    elasticities: map[Entity]f32,

    sizes: map[Entity]vec2,
    colors: map[Entity]rgba,
    playables: map[Entity]PlayableComp,
    predators: map[Entity]PredatorComp,
    gravities: map[Entity]f32,

    collidables: map[Entity]bool,
    lifetimes: map[Entity]LifeTime,
    areas: map[Entity]Area,
    points: map[Entity]u8,
    speeds: map[Entity]f32,

    collision_events: [dynamic]CollisionEvent,
    spawn_events: [dynamic]SpawnEvent,
    deletion_events: [dynamic]DeletionEvent,
    area_events: [dynamic]AreaEvent,
    point_events: [dynamic]PointEvent,
    state_events: [dynamic]StateEvent,
}
