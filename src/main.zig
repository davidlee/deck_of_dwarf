const s = @import("sdl3");
const gpu = s.gpu;
// const sdl_main = @import("s/main.zig");

const std = @import("std");

const fps = 60;
const screen_width = 1080;
const screen_height = 540;

const tilesize: i32 = 12;

const tiles_x = screen_width / (tilesize + 1);
const tiles_y = screen_height / (tilesize + 1);

//const Player = struct { x: i32, y: i32, };
//var player = Player { .x = 0, .y = 0 };

const Config = struct {
    fps: usize,
    screen_width: usize,
    screen_height: usize,
};


const World = struct {
    player: struct{ x: i32, y: i32 },
    max: struct{x: i32, y: i32},
    map: struct{},
    config: Config,

    pub fn init() !@This() {
        return @This() {
            .player = .{
                .x = 0,
                .y = 0,
            },
            .map = .{},
            .max= .{
                .x = tiles_x,
                .y = tiles_y,
            },
            .config = Config {
                .fps = 60,
                .screen_width = 1080,
                .screen_height = 540,
            },
        };
    }
};

const SpriteSheet = struct {
    path: []const u8,
    width: f32,
    height: f32,
    count: usize,
    xs: usize,
    ys: usize,
    surface: s.surface.Surface,
    texture: s.render.Texture,
    coords: std.ArrayList(s.rect.FRect),

    fn init(alloc: std.mem.Allocator, path: [:0]const u8, width: f32, height: f32, xs: usize, ys: usize, renderer: s.render.Renderer) !SpriteSheet{

        const count = xs * ys;
        const surface = try s.image.loadFile(path);
        const texture = try renderer.createTextureFromSurface(surface);
        var coords = try std.ArrayList(s.rect.FRect).initCapacity(alloc, @as(usize, @intCast(count)));

        // var sprites: [spritecount]s.rect.FRect = undefined;
        var i:usize = 0;
        // const fw:f32 = @intCast(width);
        // const fh:f32 = @intCast(height);
        for(0..ys) |y| {
            for(0..xs) |x| {
                // coords.items[i] =
                const frect = s.rect.FRect{
                    .x = 1.0 + ((1.0 + width) * @as(f32, @floatFromInt(x))),
                    .y = 1.0 + ((1.0 + height) * @as(f32, @floatFromInt(y))),
                    .w = width,
                    .h = height,
                };
                try coords.append(alloc, frect);
                i += 1;
            }
        }

        return SpriteSheet {
            .path = path,
            .width = width,
            .height = height,
            .count = xs * ys,
            .xs = xs,
            .ys = ys,
            .surface = surface,
            .texture = texture,
            .coords = coords,
        };
    }

    fn deinit(self: *SpriteSheet, alloc: std.mem.Allocator) void {
        self.surface.deinit();
        self.texture.deinit();
        self.coords.deinit(alloc);
    }
};

pub fn main() !void {

    var world = try World.init();
    defer s.shutdown();

    // Initialize SDL with subsystems you need here.
    const init_flags = s.InitFlags{ .video = true, .events = true };
    try s.init(init_flags);
    defer s.quit(init_flags);

    const window= try s.video.Window.init(
        "hello world",
        world.config.screen_width,
        world.config.screen_height,
        .{},
    );
    defer window.deinit();

    const renderer = try s.render.Renderer.init(window, null);
    defer renderer.deinit();


    // Useful for limiting the FPS and getting the delta time.
    var fps_capper = s.extras.FramerateCapper(f32){ .mode = .{ .limited = world.config.fps } };

    var gpa = std.heap.DebugAllocator(.{}){};
    const alloc= gpa.allocator();
    defer {
        _ = gpa.deinit();
    }

    var sprite_sheet = try SpriteSheet.init(
        alloc,
        "assets/urizen_onebit_tileset__v2d0.png",
        12,
        12,
        24,
        50,
        renderer
    );
    defer sprite_sheet.deinit(alloc);

    // 2679 x 651
    // const spritesize:i32 = 12;
    // const spritecount_x = 24;
    // const spritecount_y = 50;
    // const spritecount = spritecount_x * spritecount_y;
    // const spritesheet_surface = try s.image.loadFile("assets/urizen_onebit_tileset__v2d0.png");
    // const spritesheet_texture = try s.render.Renderer.createTextureFromSurface(renderer, spritesheet_surface);
    //
    // var sprites: [spritecount]s.rect.FRect = undefined;
    // var i:usize = 0;
    // for(0..spritecount_y) |y| {
    //     for(0..spritecount_x) |x| {
    //         sprites[i] = s.rect.FRect{
    //             .x = 1 + ((1 + spritesize) * @as(f32, @floatFromInt(x))),
    //             .y = 1 + ((1 + spritesize) * @as(f32, @floatFromInt(y))),
    //             .w = spritesize,
    //             .h = spritesize
    //         };
    //         i += 1;
    //     }
    // }

    var quit = false;
    while (!quit) {

        // Delay to limit the FPS, returned delta time not needed.
        _ = fps_capper.delay();

        // Update logic.

        var i:usize = 0;
        for(0..tiles_y) |y| {
            for(0..tiles_x) |x| {
                var idx: usize = 0;
                if( x == world.player.x and y == world.player.y) { idx = 38; }

                // const tileno = 7; // @mod(i, sprites.len);
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
                try s.render.Renderer.renderTexture(
                    renderer,
                    sprite_sheet.texture,
                    sprite_sheet.coords.items[idx],
                    frect
                );
                i += 1;
            }
        }

        try s.render.Renderer.present(renderer);

        // Event logic.
        while (s.events.poll()) |event|
            switch (event) {
                .quit => quit = true,
                .terminating => quit = true,
                .key_down => {
                    std.debug.print("kb: {any} // {any}\n",.{event.key_down.key.?, world});
                    keypress(event.key_down.key.?, &world);
                },
                else => {},
            };
    }
}

fn keypress(keycode: s.keycode.Keycode, world: *World) void {
    std.debug.print("kb: {any}",.{keycode});
    switch (keycode) {
        .left => {
            if (world.player.x > 0)
                world.player.x -= 1;
        },
        .right => {
            if (world.player.x < world.max.x - 1)
                world.player.x += 1;
        },
        .up => {
            if (world.player.y > 0)
                world.player.y -= 1;
        },
        .down => {
            if (world.player.y < world.max.y - 1)
                world.player.y += 1;
        },

        else => {
            std.debug.print("\n->{any}\n",.{keycode});
    },
    }
}
