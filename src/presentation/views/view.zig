// View - union of all view types, plus shared Renderable types
//
// Views are read-only lenses into World state.
// They expose what each screen needs and handle input to produce Commands.

const std = @import("std");
const s = @import("sdl3");
const infra = @import("infra");
const Command = infra.commands.Command;

const splash = @import("splash.zig");
const menu = @import("menu.zig");
const combat = @import("combat.zig");
const summary = @import("summary.zig");

// Re-export SDL types for view layer
pub const Point = s.rect.FPoint;
pub const Rect = s.rect.FRect;
pub const Color = s.pixels.Color;

// Asset identifiers - views reference assets by ID, UX resolves to textures
pub const AssetId = enum {
    splash_background,
    splash_tagline,
    // TODO: add more as needed
};

// Renderable primitives - what UX knows how to draw
pub const Renderable = union(enum) {
    sprite: Sprite,
    text: Text,
    filled_rect: FilledRect,
};

pub const Sprite = struct {
    asset: AssetId,
    dst: ?Rect = null, // null = texture's native size at (0,0)
    src: ?Rect = null, // null = entire texture
    rotation: f32 = 0,
    alpha: u8 = 255,
};

pub const Text = struct {
    content: []const u8,
    pos: Point,
    size: f32 = 16,
    color: Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
};

pub const FilledRect = struct {
    rect: Rect,
    color: Color,
};

// Input event (simplified from SDL)
pub const InputEvent = union(enum) {
    click: Point,
    key: s.keycode.Keycode,
};

// View union - active view determined by game state
pub const View = union(enum) {
    title: splash.TitleScreenView,
    menu: menu.MenuView,
    combat: combat.CombatView,
    summary: summary.SummaryView,

    pub fn handleInput(self: *View, event: InputEvent) ?Command {
        return switch (self.*) {
            .title => |*v| v.handleInput(event),
            .menu => |*v| v.handleInput(event),
            .combat => |*v| v.handleInput(event),
            .summary => |*v| v.handleInput(event),
        };
    }

    pub fn renderables(self: *const View, alloc: std.mem.Allocator) !std.ArrayList(Renderable) {
        return switch (self.*) {
            .title => |*v| v.renderables(alloc),
            .menu => |*v| v.renderables(alloc),
            .combat => |*v| v.renderables(alloc),
            .summary => |*v| v.renderables(alloc),
        };
    }
};
