const sdl3 = @import("sdl3");
// const sdl_main = @import("sdl3/main.zig");

const std = @import("std");

const fps = 60;
const screen_width = 640;
const screen_height = 480;

const tilesize: i32 = 20;

const tiles_x = screen_width / tilesize;
const tiles_y = screen_height / tilesize;

pub fn main() !void {
    defer sdl3.shutdown();

    // Initialize SDL with subsystems you need here.
    const init_flags = sdl3.InitFlags{ .video = true };
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

    // Initial window setup.
    const window = try sdl3.video.Window.init("Hello SDL3", screen_width, screen_height, .{});
    defer window.deinit();

    // Useful for limiting the FPS and getting the delta time.
    var fps_capper = sdl3.extras.FramerateCapper(f32){ .mode = .{ .limited = fps } };

    var quit = false;
    while (!quit) {

        // Delay to limit the FPS, returned delta time not needed.
        const dt = fps_capper.delay();
        _ = dt;

        // Update logic.
        const surface = try window.getSurface();
        for(0..tiles_x) |x| {
            for(0..tiles_y) |y| {
                const xi:i32 = @intCast(x);
                const yi:i32 = @intCast(y);
                const rect = sdl3.rect.IRect {.x = xi * tilesize, .y = yi * tilesize, .w = tilesize - 2, .h = tilesize - 2};
                try surface.fillRect(rect, surface.mapRgb(128, 30, 255));
            }
        }
        try window.updateSurface();

        // Event logic.
        while (sdl3.events.poll()) |event|
            switch (event) {
                .quit => quit = true,
                .terminating => quit = true,
                else => {},
            };
    }
}
