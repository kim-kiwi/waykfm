package game

import "core:math"
import rl "vendor:raylib"
import "core:fmt"

abs_f32 :: proc(v: f32) -> f32 {
    if v < 0 do return -v
    return v
}

min_f32 :: proc(a, b: f32) -> f32 {
    if a < b do return a
    return b
}

max_f32 :: proc(a, b: f32) -> f32 {
    if a < b do return a
    return b
}

check_aabb_overlap :: proc(a_pos, a_size, b_pos, b_size: vec2) -> (bool, vec2, f32) {
    a_left   := a_pos.x
    a_right  := a_pos.x + a_size.x
    a_top    := a_pos.y
    a_bottom := a_pos.y + a_size.y

    b_left   := b_pos.x
    b_right  := b_pos.x + b_size.x
    b_top    := b_pos.y
    b_bottom := b_pos.y + b_size.y

    if a_right <= b_left || a_left >= b_right ||
       a_bottom <= b_top || a_top >= b_bottom {
        return false, vec2{}, 0
    }

    // 각 방향으로 얼마나 밀어내야 하는지
    overlap_left   := a_right - b_left    // A를 왼쪽으로 밀 때
    overlap_right  := b_right - a_left    // A를 오른쪽으로 밀 때
    overlap_up     := a_bottom - b_top    // A를 위로 밀 때
    overlap_down   := b_bottom - a_top    // A를 아래로 밀 때

    min_overlap := overlap_left
    normal := vec2{-1, 0}

    if overlap_right < min_overlap {
        min_overlap = overlap_right
        normal = vec2{1, 0}
    }

    if overlap_up < min_overlap {
        min_overlap = overlap_up
        normal = vec2{0, -1}
    }

    if overlap_down < min_overlap {
        min_overlap = overlap_down
        normal = vec2{0, 1}
    }

    return true, normal, min_overlap
}

resolve_collision :: proc(world: ^World, a: Entity, b: Entity) -> (is_hit: bool) {
    hit, normal, penetration := check_aabb_overlap(
        world.positions[a],
        world.sizes[a],
        world.positions[b],
        world.sizes[b],
    )
    is_hit = hit

    if !hit {
        return
    }

    inv_mass_a: f32 = world.inv_mass[a]
    inv_mass_b: f32 = world.inv_mass[b]
    inv_mass_sum := inv_mass_a + inv_mass_b

    if inv_mass_sum == 0 {
        return
    }

    // 1. 위치 보정: 겹친 만큼 밀어내기
    percent: f32 = 1.0
    slop: f32 = 0.0

    correction_mag := max(penetration - slop, 0) / inv_mass_sum * percent
    correction := normal * correction_mag /* vec2{
        normal.x * correction_mag,
        normal.y * correction_mag,
    } */

    world.positions[a] += correction * inv_mass_a
    world.positions[b] -= correction * inv_mass_b

    // 2. 속도 보정
    rv := world.velocities[a]-world.velocities[b] /* vec2{
        world.velocities[b].x - world.velocities[a].x,
        world.velocities[b].y - world.velocities[a].y,
    } */

    vel_along_normal := rv.x * normal.x + rv.y * normal.y

    // 이미 서로 멀어지는 중이면 속도 충돌 처리는 안 함
    if vel_along_normal > 0 {
        return
    }

    e := f32(world.elasticities[a]+world.elasticities[b])*0.5

    j := -(1 + e) * vel_along_normal
    j /= inv_mass_sum

    impulse := normal * j

    world.velocities[a] += impulse * inv_mass_a
    world.velocities[b] -= impulse * inv_mass_b
    return
}

collision_system :: proc(world: ^World) {
    for e1, pos in world.positions {
        if !(e1 in world.positions) do continue
        has_vel := e1 in world.velocities
        if !has_vel do continue
        has_e := e1 in world.elasticities
        if !has_e do continue
        imass1, has_imass := world.inv_mass[e1]
        if !has_imass do continue
        has_size := e1 in world.sizes
        if !has_size do continue
        // rl.DrawText(rl.TextFormat("%f",vel.x),i32(pos.x),i32(pos.y-20),20,rl.RED)
        for e2, pos in world.positions {
            if e2 <= e1 do continue
            if !(e2 in world.positions) do continue
            has_vel := e2 in world.velocities
            if !has_vel do continue
            has_e := e2 in world.elasticities
            if !has_e do continue
            imass2, has_imass := world.inv_mass[e2]
            if !has_imass || (imass1==0 && imass2==0) do continue
            has_size := e2 in world.sizes
            if !has_size do continue

            if resolve_collision(world,e1,e2) {
                append(&world.collision_events,CollisionEvent{a=e1, b=e2})
            }
        }
    }
}

rigidbody_system :: proc(world: ^World) {
    for e, &pos in world.positions {
        vel, has_vel := world.velocities[e]
        if !has_vel do continue
        friction, has_friction := world.frictions[e]
        if !has_friction do continue
        // elasticity, has_elasticity := world.elasticities[e]
        // if !has_elasticity do continue

        pos+=vel*rl.GetFrameTime()
        vel*=math.pow(1-friction,rl.GetFrameTime())

        world.positions[e]=pos
        world.velocities[e]=vel
    }
}
predator_system :: proc(world: ^World) {
    for ev in world.collision_events {
        if ev.a in world.predator && world.predator[ev.a].target == ev.b do append(&world.deletion_events, DeletionEvent{target=ev.b})
        if ev.b in world.predator && world.predator[ev.b].target == ev.a do append(&world.deletion_events, DeletionEvent{target=ev.a})
    }

    for e1, predator in world.predator {
        e1pos, has_pos := world.positions[e1]
        if !has_pos do continue
        e1vel, has_vel := world.velocities[e1]
        if !has_vel do continue

        e2 := predator.target
        e2pos, e2has_pos := world.positions[e2]
        if !e2has_pos do continue
        e2vel, e2has_vel := world.velocities[e2]
        if !e2has_vel do continue
        e1vel += rl.Vector2Normalize(e2pos-e1pos)*200*rl.GetFrameTime()

        world.velocities[e1] = e1vel
    }
}
input_system :: proc(world: ^World) {
    for e, input in world.inputs {
        vel, has_vel := world.velocities[e]
        if !has_vel do continue
        movement: vec2
        if rl.IsKeyDown(.A) do movement.x-=1
        if rl.IsKeyDown(.D) do movement.x+=1
        if rl.IsKeyDown(.W) do movement.y-=1
        if rl.IsKeyDown(.S) do movement.y+=1
        vel += rl.Vector2Normalize(movement)*175*rl.GetFrameTime()
        world.velocities[e] = vel
    }
}

render_system :: proc(world: ^World) {
    center_x, center_y := f32(rl.GetScreenWidth()/2), f32(rl.GetScreenHeight()/2)
    for e, &pos in world.positions {
        size, has_size := world.sizes[e]
        color, has_color := world.colors[e]
        if !has_size do continue
        if !has_color do continue

        rl.DrawRectangleV(pos+{center_x,center_y},size,rl.Color(color))

        // vel, has_vel := world.velocities[e]
        // if has_vel {
        //     rl.DrawLineEx(pos+(size*0.5),pos+vel,5,rl.GREEN)
        // }
    }
}

deletion_system :: proc(world: ^World) {
    for ev in world.deletion_events {
        entity_delete(world,ev.target)
    }
}

clear_system :: proc(world: ^World) {
    clear(&world.collision_events)
    clear(&world.deletion_events)
}
