const s = @import("sdl3");
const gpu = s.gpu;
// const sdl_main = @import("s/main.zig");

const std = @import("std");

const fps = 60;
const screen_width = 1080;
const screen_height = 540;

const tilesize: i32 = 12;

const tiles_x = screen_width / tilesize;
const tiles_y = screen_height / tilesize;

pub fn main() !void {
    defer s.shutdown();

    // Initialize SDL with subsystems you need here.
    const init_flags = s.InitFlags{ .video = true, .events = true };
    try s.init(init_flags);
    defer s.quit(init_flags);

    // const window, const renderer = try s.render.Renderer.initWithWindow(
    //     "hello world",
    //     screen_width,
    //     screen_height,
    //     .{ .open_gl = true, .resizable = true }
    // );
    //
    const window= try s.video.Window.init(
        "hello world",
        screen_width,
        screen_height,
        .{},
        // .{ .open_gl = true, .resizable = true }
    );
    const renderer = try s.render.Renderer.init(window, null);
        // s.render.Renderer.init(window, "lovely renderer");

    defer window.deinit();
    // _ = renderer;


    // Useful for limiting the FPS and getting the delta time.
    var fps_capper = s.extras.FramerateCapper(f32){ .mode = .{ .limited = fps } };

    // 2679 x 651
    const spritesize:i32 = 12;
    const spritecount_x = 24;
    const spritecount_y = 50;
    const spritecount = spritecount_x * spritecount_y;
    const spritesheet_surface = try s.image.loadFile("assets/urizen_onebit_tileset__v2d0.png");
    const spritesheet_texture = try s.render.Renderer.createTextureFromSurface(renderer, spritesheet_surface);

    var sprites: [spritecount]s.rect.FRect = undefined;
    var i:usize = 0;
    for(0..spritecount_y) |y| {
        for(0..spritecount_x) |x| {
            sprites[i] = s.rect.FRect{
                .x = 1 + ((1 + spritesize) * @as(f32, @floatFromInt(x))),
                .y = 1 + ((1 + spritesize) * @as(f32, @floatFromInt(y))),
                .w = spritesize,
                .h = spritesize
            };
            i += 1;
        }
    }
    const SpriteName = enum(usize) {
        bg,
        fg,
    };

    _ = .{SpriteName, sprites};

    var quit = false;
    while (!quit) {

        // Delay to limit the FPS, returned delta time not needed.
        _ = fps_capper.delay();

        // Update logic.

        // const surface = try window.getSurface();
        // try surface.fillRect(null, surface.mapRgb(128, 30, 255));
        // try window.updateSurface();

        i = 0;
        for(0..tiles_y) |y| {
            for(0..tiles_x) |x| {
                const tileno = 7; // @mod(i, sprites.len);
                const tf:f32 = @floatFromInt(tilesize);
                const xf:f32 = @floatFromInt(x);
                const xx:f32 = (tf + 1) * xf;
                const yf:f32 = @floatFromInt(y);
                const yy:f32 = (tf + 1) * yf;
                const frect = s.rect.FRect {
                    .x = xx,
                    .y = yy,
                    .w = tf,
                    .h = tf
                };
                try s.render.Renderer.renderTexture(renderer, spritesheet_texture, sprites[tileno], frect);
                i += 1;
            }
        }
        try s.render.Renderer.present(renderer);

        // Event logic.
        while (s.events.poll()) |event|
            switch (event) {
                .quit => quit = true,
                .terminating => quit = true,
                else => {},
            };
    }
}
