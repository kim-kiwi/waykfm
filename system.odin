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

resolve_overlap :: proc(world: ^World, a: Entity, b: Entity) -> (is_hit: bool, hit_normal: vec2) {
    hit, normal, penetration := check_aabb_overlap(
        world.positions[a],
        world.sizes[a],
        world.positions[b],
        world.sizes[b],
    )
    is_hit = hit
    hit_normal = normal

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
    correction := normal * correction_mag

    world.positions[a] += correction * inv_mass_a
    world.positions[b] -= correction * inv_mass_b

    return
}

resolve_collision :: proc(world: ^World, a: Entity, b: Entity, normal: vec2) {
    inv_mass_a: f32 = world.inv_mass[a]
    inv_mass_b: f32 = world.inv_mass[b]
    inv_mass_sum := inv_mass_a + inv_mass_b

    if inv_mass_sum == 0 {
        return
    }

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

overlap_resolution_system :: proc(world: ^World) {
    for e1 in world.positions {
        has_vel := e1 in world.velocities
        if !has_vel do continue
        has_e := e1 in world.elasticities
        if !has_e do continue
        imass1, has_imass := world.inv_mass[e1]
        if !has_imass do continue
        has_size := e1 in world.sizes
        if !has_size do continue
        for e2 in world.positions {
            if e2 == e1 do continue
            has_vel := e2 in world.velocities
            if !has_vel do continue
            has_e := e2 in world.elasticities
            if !has_e do continue
            imass2, has_imass := world.inv_mass[e2]
            if !has_imass || (imass1==0 && imass2==0) do continue
            has_size := e2 in world.sizes
            if !has_size do continue
            if hit, normal := resolve_overlap(world,e1,e2); hit {
                append(&world.collision_events,CollisionEvent{e1, e2, normal})
            }
        }
    }
}

collision_resolution_system :: proc(world: ^World) {
    for ev in world.collision_events {
        resolve_collision(world, ev.a, ev.b, ev.normal)
    }
}

// collision_system :: proc(world: ^World) {
//     for e1 in world.positions {
//         has_vel := e1 in world.velocities
//         if !has_vel do continue
//         has_e := e1 in world.elasticities
//         if !has_e do continue
//         imass1, has_imass := world.inv_mass[e1]
//         if !has_imass do continue
//         has_size := e1 in world.sizes
//         if !has_size do continue
//         for e2 in world.positions {
//             if e2 <= e1 do continue
//             has_vel := e2 in world.velocities
//             if !has_vel do continue
//             has_e := e2 in world.elasticities
//             if !has_e do continue
//             imass2, has_imass := world.inv_mass[e2]
//             if !has_imass || (imass1==0 && imass2==0) do continue
//             has_size := e2 in world.sizes
//             if !has_size do continue
//         }
//     }
// }

debug_system :: proc(world: ^World) {
    // fmt.println("====================")
    for e in world.positions {
        pos := world.positions[e]
        size, has_size := world.sizes[e]
        if !has_size do continue
        vel, has_vel := world.velocities[e]
        if !has_vel do continue
        friction, has_friction := world.frictions[e]
        if !has_friction do continue
        // elasticity, has_elasticity := world.elasticities[e]
        // if !has_elasticity do continue

        dt := rl.GetFrameTime()

        moving := AABB{pos,pos+size}
        earliest := NIL_ENTITY
        earliest_hit := SweptHit {
            hit = false,
            time = 1.0,
            normal = {0,0},
        }

        for e2, &e2pos in world.positions {
            if e2 == e do continue
            e2size, has_size := world.sizes[e2]
            if !has_size do continue
            e2vel, has_vel := world.velocities[e2]
            if !has_vel do continue
            e2friction, has_friction := world.frictions[e2]
            if !has_friction do continue

            delta := (vel-e2vel)
            hit := swept_aabb(moving,{e2pos,e2pos+e2size},delta)

            if hit.hit && hit.time < earliest_hit.time {
                earliest = e2
                earliest_hit = hit
            }
        }

        // pos+=vel*dt*earliest_hit.time
        // if earliest_hit.hit {
        // }
        center:=vec2{f32(rl.GetScreenWidth())/2,f32(rl.GetScreenHeight())/2}
        // fmt.println(e,earliest,earliest_hit,pos+center,pos+vel*earliest_hit.time+center,vel)
        rl.DrawLineEx(pos+center,pos+vel*earliest_hit.time+center,2,earliest_hit.hit ? rl.RED : rl.GREEN)
        rl.DrawRectangleV(pos+vel*earliest_hit.time+center,size,earliest_hit.hit ? rl.RED : rl.GREEN)
        // if entity_valid(earliest) {
        //     // next_positions[earliest]=world.positions[e] + world.velocities[earliest]*dt*earliest_hit.time
        // }
    }
}

rigidbody_system :: proc(world: ^World) {
    for e in world.positions {
        pos := world.positions[e]
        size, has_size := world.sizes[e]
        if !has_size do continue
        vel, has_vel := world.velocities[e]
        if !has_vel do continue
        friction, has_friction := world.frictions[e]
        if !has_friction do continue
        // elasticity, has_elasticity := world.elasticities[e]
        // if !has_elasticity do continue

        dt := rl.GetFrameTime()

        pos+=vel*dt
        vel*=math.pow(1-friction,rl.GetFrameTime())

        world.positions[e]=pos
        world.velocities[e]=vel
    }
}
predator_system :: proc(world: ^World) {
    // for ev in world.collision_events {
    //     if ev.a in world.predators && world.predators[ev.a].target == ev.b do append(&world.deletion_events, DeletionEvent{ev.b})
    //     if ev.b in world.predators && world.predators[ev.b].target == ev.a do append(&world.deletion_events, DeletionEvent{ev.a})
    // }

    for e1, predator in world.predators {
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
    for e, input in world.playables {
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

gameover_system :: proc(world: ^World) {
    for ev in world.deletion_events {
        if ev.entity in world.playables {
            world.gameover=true
            world.gameover_end_at=rl.GetTime()
        }
    }
    if world.gameover {
        if rl.GetTime() - world.gameover_end_at > 1 {
            world.should_restart=true
        }
    }
}

spawn_system :: proc(world: ^World) {
    for ev in world.spawn_events {
        switch ev.kind {
        case .Player:
            spawn_player(world)
        case .Enemy:
            spawn_enemy(world,ev.target)
        case .Square:
            spawn_square(world,ev.pos,ev.size,ev.vel,ev.inv_mass)
        }
    }
}

deletion_system :: proc(world: ^World) {
    for ev in world.deletion_events {
        entity_delete(world,ev.entity)
    }
}

clear_system :: proc(world: ^World) {
    clear(&world.collision_events)
    clear(&world.spawn_events)
    clear(&world.deletion_events)
}
