package game

import "core:fmt"

get_rgba :: #force_inline proc(hex: u32) -> rgba {
    return (transmute([4]u8)hex).wzyx
}
