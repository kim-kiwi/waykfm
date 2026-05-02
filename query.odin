// 언젠가 사용 예정...

package game

RigidBody_View :: struct {
    pos: ^vec2,
    size: ^vec2,
    vel: ^vec2,
    elas: ^f32,
    imass: ^f32,
}

get_rigidbody :: proc(world: ^World, e: Entity) -> (^RigidBody_View, bool) {
    pos, has_pos := world.positions[e]
    if !has_pos do return {}, false
    size, has_size := world.sizes[e]
    if !has_size do return {}, false
    vel, has_vel := world.velocities[e]
    if !has_vel do return {}, false
    elas, has_elas := world.elasticities[e]
    if !has_elas do return {}, false
    imass, has_imass := world.inv_mass[e]
    if !has_imass do return {}, false
    view := new(RigidBody_View)
    view^ = { pos=&pos, size=&size, vel=&vel, elas=&elas, imass=&imass }
    return view, true
}
