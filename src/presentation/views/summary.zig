// SummaryView - encounter summary / loot screen
//
// Displays rewards, stats, loot choices after combat.

const std = @import("std");
const view = @import("view.zig");
const infra = @import("infra");
const World = @import("../../domain/world.zig").World;

const Renderable = view.Renderable;
const InputEvent = view.InputEvent;
const Command = infra.commands.Command;

pub const SummaryView = struct {
    world: *const World,

    pub fn init(world: *const World) SummaryView {
        return .{ .world = world };
    }

    pub fn handleInput(self: *SummaryView, event: InputEvent) ?Command {
        _ = self;
        switch (event) {
            .click => |_| {
                // TODO: hit test loot selection, continue button
                return null;
            },
            .key => |_| {
                return null;
            },
        }
    }

    pub fn renderables(self: *const SummaryView, alloc: std.mem.Allocator) !std.ArrayList(Renderable) {
        _ = self;
        const list = try std.ArrayList(Renderable).initCapacity(alloc, 16);
        // TODO: add summary renderables
        // - victory/defeat banner
        // - rewards list
        // - loot choices
        // - continue button
        return list;
    }
};
