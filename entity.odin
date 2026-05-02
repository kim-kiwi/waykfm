package game

import "core:fmt"

entity_valid :: proc(e: Entity) -> bool {
    return e != NIL_ENTITY
}

entity_create :: proc(world: ^World) -> Entity {
    world.next_entity += 1
    world.entities[world.next_entity] = true
    return world.next_entity
}

entity_delete :: proc(world: ^World, e: Entity) {
    if e == NIL_ENTITY do return
    // delete_key(world,e)
    delete_key(&world.entities,e)

    delete_key(&world.positions,e)
    delete_key(&world.velocities,e)
    delete_key(&world.inv_mass,e)
    delete_key(&world.frictions,e)
    delete_key(&world.elasticities,e)

    delete_key(&world.sizes,e)
    delete_key(&world.colors,e)
    delete_key(&world.playables,e)
    delete_key(&world.predators,e)
    delete_key(&world.gravities,e)

    delete_key(&world.collidables,e)
    delete_key(&world.lifetimes,e)
}
