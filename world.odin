package game

PredatorComp :: struct {
    target: Entity,
}

CollisionEvent :: struct {
    a: Entity,
    b: Entity,

}
DeletionEvent :: struct {
    target: Entity,
}

World :: struct {
    next_entity: Entity,

    positions: map[Entity]vec2,
    velocities: map[Entity]vec2,
    inv_mass: map[Entity]f32,
    frictions: map[Entity]f32,
    elasticities: map[Entity]f32,
    sizes: map[Entity]vec2,
    colors: map[Entity]rgba,
    inputs: map[Entity]bool,
    predator: map[Entity]PredatorComp,
    prey: map[Entity]bool,

    collision_events: [dynamic]CollisionEvent,
    deletion_events: [dynamic]DeletionEvent,
}
