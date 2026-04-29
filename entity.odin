package game

import "core:fmt"

entity_create :: proc(world: ^World) -> Entity {
    e := world.next_entity
    world.next_entity = Entity(u32(world.next_entity)+1)
    return e
}

entity_delete :: proc(world: ^World, e: Entity) {
    // delete_key(world,e)
    delete_key(&world.positions,e)
    delete_key(&world.velocities,e)
    delete_key(&world.inv_mass,e)
    delete_key(&world.frictions,e)
    delete_key(&world.elasticities,e)
    delete_key(&world.sizes,e)
    delete_key(&world.colors,e)
    delete_key(&world.inputs,e)
    delete_key(&world.predator,e)
    delete_key(&world.prey,e)
}
