// MenuView - main menu screen
//
// Displays menu options, handles menu navigation.

const std = @import("std");
const view = @import("view.zig");
const infra = @import("infra");
const World = @import("../../domain/world.zig").World;

const Renderable = view.Renderable;
const InputEvent = view.InputEvent;
const Command = infra.commands.Command;

pub const MenuView = struct {
    world: *const World,

    pub fn init(world: *const World) MenuView {
        return .{ .world = world };
    }

    pub fn handleInput(self: *MenuView, event: InputEvent) ?Command {
        _ = self;
        switch (event) {
            .click => |_| {
                // TODO: hit test menu buttons
                return Command{ .start_game = {} };
            },
            .key => |_| {
                return null;
            },
        }
    }

    pub fn renderables(self: *const MenuView, alloc: std.mem.Allocator) !std.ArrayList(Renderable) {
        _ = self;
        const list = try std.ArrayList(Renderable).initCapacity(alloc, 8);
        // TODO: add menu renderables
        // - title sprite
        // - menu buttons
        return list;
    }
};
