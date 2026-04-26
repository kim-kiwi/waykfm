package game

create_entity :: proc(world: ^World) -> Entity {
    e := world.next_entity
    world.next_entity = Entity(u32(world.next_entity)+1)
    return e
}
