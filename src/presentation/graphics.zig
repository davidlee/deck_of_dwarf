const std = @import("std");
const lib = @import("infra");
const Cast = lib.util.Cast;
const s = @import("sdl3");
const rect = s.rect;
const view = @import("views/view.zig");
const card_renderer = @import("card_renderer.zig");
const AssetId = view.AssetId;
const Renderable = view.Renderable;
const CardRenderer = card_renderer.CardRenderer;

const font_path = "assets/font/Caudex-Bold.ttf";
const tagline_text = "When life gives you goblins, make goblinade.";

// Asset registry - indexed by AssetId
const AssetCount = @typeInfo(AssetId).@"enum".fields.len;

// const ReferenceResolution = struct {
//     w: u32,
//     h: u32,
//     name: []const u8,
// };
//
// const resolutions = [_]ReferenceResolution{
//     .{ .w = 1280, .h = 720, .name = "720p" },
//     .{ .w = 1920, .h = 1080, .name = "1080p" },
//     .{ .w = 2560, .h = 1440, .name = "1440p" },
// };
//
// const Layout = struct {
//     // Computed from logical size
//     screen: Rect,
//
//     // Major regions
//     sidebar: Rect,
//     main_area: Rect,
//     top_bar: Rect,
//
//     fn compute(logical_w: f32, logical_h: f32) Layout {
//         const sidebar_w = 250;
//         return .{
//             .screen = .{ .x = 0, .y = 0, .w = logical_w, .h = logical_h },
//             .sidebar = .{ .x = logical_w - sidebar_w, .y = 0, .w = sidebar_w, .h = logical_h },
//             .main_area = .{ .x = 0, .y = 40, .w = logical_w - sidebar_w, .h = logical_h - 40 },
//             .top_bar = .{ .x = 0, .y = 0, .w = logical_w, .h = 40 },
//         };
//     }
// };

pub const UX = struct {
    alloc: std.mem.Allocator,
    renderer: s.render.Renderer,
    window: s.video.Window,
    fps_capper: s.extras.FramerateCapper(f32),
    assets: [AssetCount]?s.render.Texture,
    cards: CardRenderer,
    font: s.ttf.Font,

    const SpriteEntry = struct {
        filename: [:0]const u8,
        id: AssetId,
        scale_mode: s.surface.ScaleMode = .nearest,
    };

    // Sprites loaded after splash (splash is special - needed for logical presentation size)
    const sprites = [_]SpriteEntry{
        .{ .filename = "assets/halberdier.png", .id = .player_halberdier },
        .{ .filename = "assets/fredrick-snail.png", .id = .fredrick_snail },
        .{ .filename = "assets/mob-thief.png", .id = .thief },
        .{ .filename = "assets/end-turn.png", .id = .end_turn },
    };

    fn loadSprites(assets: *[AssetCount]?s.render.Texture, renderer: s.render.Renderer) !void {
        for (sprites) |entry| {
            const tex = try s.image.loadTexture(renderer, entry.filename);
            try tex.setScaleMode(entry.scale_mode);
            assets[@intFromEnum(entry.id)] = tex;
        }
    }

    /// initialise the presentation layer
    pub fn init(alloc: std.mem.Allocator, config: *const lib.config.Config) !UX {
        const window = try s.video.Window.init(
            "Deck of Dwarf",
            config.width,
            config.height,
            .{ .resizable = true, .vulkan = true },
        );
        errdefer window.deinit();

        var renderer = try s.render.Renderer.init(
            window,
            null,
        );

        // Load assets
        var assets: [AssetCount]?s.render.Texture = .{null} ** AssetCount;

        const splash_bg = try s.image.loadTexture(renderer, "assets/dod_menu.png");
        assets[@intFromEnum(AssetId.splash_background)] = splash_bg;

        // Set logical presentation based on splash background size
        try renderer.setLogicalPresentation(config.logical_width, config.logical_height, .letter_box);

        try loadSprites(&assets, renderer);

        // Load font (kept alive for card rendering)
        try s.ttf.init();
        const font = try s.ttf.Font.init(font_path, 24);
        errdefer font.deinit();

        // Pre-render tagline
        const white: s.ttf.Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 };
        assets[@intFromEnum(AssetId.splash_tagline)] = try textureFromSurface(
            renderer,
            try font.renderTextBlended(tagline_text, white),
        );

        return UX{
            .alloc = alloc,
            .window = window,
            .renderer = renderer,
            .fps_capper = s.extras.FramerateCapper(f32){ .mode = .{ .limited = config.fps } },
            .assets = assets,
            .cards = CardRenderer.init(alloc, renderer, font),
            .font = font,
        };
    }

    pub fn deinit(self: *UX) void {
        self.cards.deinit();
        self.font.deinit();
        s.ttf.quit();
        for (&self.assets) |*asset| {
            if (asset.*) |tex| tex.deinit();
        }
        self.renderer.deinit();
        self.window.deinit();
    }

    pub fn getTexture(self: *const UX, id: AssetId) ?s.render.Texture {
        return self.assets[@intFromEnum(id)];
    }

    // Convert screen coordinates to logical coordinates (accounts for scaling/letterbox)
    pub fn translateCoords(self: *UX, screen: rect.FPoint) rect.FPoint {
        return self.renderer.renderCoordinatesFromWindowCoordinates(screen) catch screen;
    }

    /// MAIN RENDER LOOP
    ///
    /// Render a list of renderables
    pub fn renderView(self: *UX, renderables: []const Renderable) !void {
        // clear
        try self.renderer.setDrawColor(s.pixels.Color{ .r = 0, .g = 0, .b = 0 });
        try self.renderer.clear();

        // layer 0: background
        //

        // layer 1: game content
        for (renderables) |r| {
            switch (r) {
                .sprite => |sprite| try self.renderSprite(sprite),
                .filled_rect => |fr| try self.renderFilledRect(fr),
                .card => |card| try self.renderCard(card),
                .text => {
                    // TODO: dynamic text rendering
                },
            }
        }

        // layer 2: UI chrome
        // self.renderUI( ... )

        // layer 3: overlays (tooltips, etc)
        //

        // layer 4: debug border, etc
        try self.renderDebug();

        try self.renderer.present();
    }

    fn renderDebug(self: *UX) !void {
        try self.renderer.setDrawColor(s.pixels.Color{ .r = 80, .g = 70, .b = 30 });
        const w, const h, _ = try self.renderer.getLogicalPresentation();
        const border = s.rect.FRect{ .x = 0, .y = 0, .w = @floatFromInt(w), .h = @floatFromInt(h) };
        try self.renderer.renderRect(border);
    }

    fn renderCard(self: *UX, card: view.Card) !void {
        const tex = try self.cards.getCardTexture(card.model);
        const tex_w, const tex_h = try tex.getSize();

        const src = rect.FRect{ .x = 0, .y = 0, .w = tex_w, .h = tex_h };
        try self.renderer.renderTexture(tex, src, card.dst);
    }

    fn renderSprite(self: *UX, sprite: view.Sprite) !void {
        const tex = self.getTexture(sprite.asset) orelse return;
        const tex_w, const tex_h = try tex.getSize();

        const src = sprite.src orelse rect.FRect{ .x = 0, .y = 0, .w = tex_w, .h = tex_h };
        const dst = if (sprite.dst) |d|
            // Use provided dst, but substitute texture size if w/h are 0
            rect.FRect{
                .x = d.x,
                .y = d.y,
                .w = if (d.w == 0) tex_w else d.w,
                .h = if (d.h == 0) tex_h else d.h,
            }
        else
            rect.FRect{ .x = 0, .y = 0, .w = tex_w, .h = tex_h };

        try self.renderer.renderTexture(tex, src, dst);
    }

    fn renderFilledRect(self: *UX, fr: view.FilledRect) !void {
        try self.renderer.setDrawColor(fr.color);
        try self.renderer.renderFillRect(fr.rect);
    }
};

fn textureFromSurface(renderer: s.render.Renderer, surface: s.surface.Surface) !s.render.Texture {
    defer surface.deinit();
    return try renderer.createTextureFromSurface(surface);
}
