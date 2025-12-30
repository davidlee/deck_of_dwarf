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
const Rect = s.rect.FRect;
const AssetId = view.AssetId;
const Color = s.pixels.Color;

const Button = struct {
    rect: Rect,
    color: Color,
    asset_id: ?AssetId,
    text: []const u8,
};

// FIXME: set reference dimensions in view.zig

pub const logical_h = 1920;
pub const logical_w = 1080;

pub const header_h = 100;
pub const footer_h = 100;
pub const sidebar_w = 700;

pub const origin = s.rect.FPoint{ .x = 0, .y = header_h };
pub const viewport = Rect{
    .x = origin.x,
    .y = origin.y,
    .w = logical_w - sidebar_w,
    .h = logical_h - header_h - footer_h,
};

const MenuBar = struct {
    fn render() []const Renderable {
        return &[_]Renderable{
            // top
            .{ .filled_rect = .{
                .rect = .{
                    .x = 0,
                    .y = 0,
                    .w = logical_w,
                    .h = header_h,
                },
                .color = Color{ .r = 30, .g = 30, .b = 30 },
            } },
            // RHS
            .{ .filled_rect = .{
                .rect = .{
                    .x = logical_w - sidebar_w,
                    .y = header_h,
                    .w = sidebar_w,
                    .h = logical_h - header_h - footer_h,
                },
                .color = Color{ .r = 30, .g = 30, .b = 30 },
            } },

            // footer
            .{ .filled_rect = .{
                .rect = .{
                    .x = 0,
                    .y = 1080 - footer_h,
                    .w = 1920,
                    .h = footer_h,
                },
                .color = Color{ .r = 30, .g = 30, .b = 30 },
            } },
            // footer
        };
    }
};

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

        try list.appendSlice(alloc, MenuBar.render());
    }
};
