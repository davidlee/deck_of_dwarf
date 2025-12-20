const std = @import("std");
const World = @import("world.zig").World;
const lib = @import("infra");
const s = lib.sdl;

pub fn keypress(keycode: s.keycode.Keycode, world: *World) bool {
    _ = world;
    switch (keycode) {
        // .left => {
        // },
        // .right => {
        // },
        // .up => {
        // },
        // .down => {
        // },
        .escape => {
            return true;
        },
        else => {},
    }
    return false;
}
