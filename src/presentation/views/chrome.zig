// ChromeView - main menu screen
//
// Displays menu options, handles menu navigation.

const std = @import("std");
const view = @import("view.zig");
const infra = @import("infra");
const s = @import("sdl3");
const World = @import("../../domain/world.zig").World;

const Renderable = view.Renderable;
const ViewState = view.ViewState;
const InputResult = view.InputResult;
const Command = infra.commands.Command;

pub const ChromeView = struct {
    world: *const World,

    pub fn init(world: *const World) ChromeView {
        return .{ .world = world };
    }

    pub fn handleInput(self: *ChromeView, event: s.events.Event, world: *const World, vs: ViewState) InputResult {
        _ = self;
        _ = event;
        _ = world;
        _ = vs;
        return .{};
    }

    pub fn appendRenderables(self: *const ChromeView, alloc: std.mem.Allocator, vs: ViewState, list: *std.ArrayList(Renderable)) !void {
        //
        _ = .{ self, alloc, vs, list };

        for (0..0) |_| {
            list.append(alloc, .{});
        }
    }
};
