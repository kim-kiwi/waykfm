package game

import "core:math"

EPS :: f32(1e-6)

AABB :: struct {
    min: vec2,
    max: vec2,
}

SweptHit :: struct {
    hit: bool,
    time: f32,
    normal: vec2,
}

swept_aabb :: proc(a: AABB, b: AABB, delta: vec2) -> SweptHit {
    result := SweptHit {
        hit = false,
        time = 1.0,
        normal = {0, 0},
    }

    x_entry: f32
    y_entry: f32
    x_exit: f32
    y_exit: f32

    if delta.x > 0 {
        x_entry = b.min.x - a.max.x
        x_exit  = b.max.x - a.min.x
    } else {
        x_entry = b.max.x - a.min.x
        x_exit  = b.min.x - a.max.x
    }

    if delta.y > 0 {
        y_entry = b.min.y - a.max.y
        y_exit  = b.max.y - a.min.y
    } else {
        y_entry = b.max.y - a.min.y
        y_exit  = b.min.y - a.max.y
    }

    entry_time_x: f32
    exit_time_x: f32
    entry_time_y: f32
    exit_time_y: f32

    big := f32(1.0e30)

    if math.abs(delta.x) < EPS {
        // x축으로 움직이지 않는데 x축에서 이미 떨어져 있으면 절대 충돌 불가
        if a.max.x <= b.min.x || a.min.x >= b.max.x {
            return result
        }

        entry_time_x = -big
        exit_time_x = big
    } else {
        entry_time_x = x_entry / delta.x
        exit_time_x = x_exit / delta.x
    }

    if math.abs(delta.y) < EPS {
        // y축으로 움직이지 않는데 y축에서 이미 떨어져 있으면 절대 충돌 불가
        if a.max.y <= b.min.y || a.min.y >= b.max.y {
            return result
        }

        entry_time_y = -big
        exit_time_y = big
    } else {
        entry_time_y = y_entry / delta.y
        exit_time_y = y_exit / delta.y
    }

    entry_time := max(entry_time_x, entry_time_y)
    exit_time := min(exit_time_x, exit_time_y)

    if entry_time > exit_time {
        return result
    }

    if entry_time < 0 || entry_time > 1 {
        return result
    }

    result.hit = true
    result.time = entry_time

    if entry_time_x > entry_time_y {
        if delta.x > 0 {
            result.normal = {-1, 0}
        } else {
            result.normal = {1, 0}
        }
    } else {
        if delta.y > 0 {
            result.normal = {0, -1}
        } else {
            result.normal = {0, 1}
        }
    }

    return result
}
