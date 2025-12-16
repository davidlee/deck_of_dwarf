const std = @import("std");
const znoise = @import("znoise");
const World = @import("model").World;

pub fn generateTerrain(alloc: std.mem.Allocator, world: *World) !void {
    const gen = znoise.FnlGenerator{};

    for (0..world.max.y) |y|
        for (0..world.max.x) |x| {
            const v = gen.noise2(@floatFromInt(x), @floatFromInt(y));
            try world.map.append(alloc, (if (v > 0.3) 0 else 14));
        };
}
