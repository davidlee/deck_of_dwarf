// CombatView - combat encounter screen
//
// Displays player hand, enemies, engagements, combat phase.
// Handles card selection, targeting, reactions.

const std = @import("std");
const view = @import("view.zig");
const infra = @import("infra");
const World = @import("../../domain/world.zig").World;
const cards = @import("../../domain/cards.zig");
const combat = @import("../../domain/combat.zig");
const s = @import("sdl3");

const Renderable = view.Renderable;
const InputEvent = view.InputEvent;
const Point = view.Point;
const Rect = view.Rect;
const CardViewModel = view.CardViewModel;
const CardState = view.CardState;
const Command = infra.commands.Command;
const ID = infra.commands.ID;
const Keycode = s.keycode.Keycode;
const card_renderer = @import("../card_renderer.zig");

pub const CombatView = struct {
    world: *const World,

    pub fn init(world: *const World) CombatView {
        return .{ .world = world };
    }

    // Query methods - expose what the view needs from World

    pub fn playerHand(self: *const CombatView) []const *cards.Instance {
        return self.world.player.cards.deck.hand.items;
    }

    pub fn enemies(self: *const CombatView) []const *combat.Agent {
        if (self.world.encounter) |*enc| {
            return enc.enemies.items;
        }
        return &.{};
    }

    pub fn combatPhase(self: *const CombatView) World.GameState {
        return self.world.fsm.currentState();
    }

    // Input handling

    pub fn handleInput(self: *CombatView, event: InputEvent) ?Command {
        switch (event) {
            .click => |pos| return self.handleClick(pos),
            .key => |keycode| return self.handleKey(keycode),
        }
    }

    fn handleClick(self: *CombatView, pos: Point) ?Command {
        // Hit test cards in hand
        if (self.hitTestHand(pos)) |card_id| {
            std.debug.print("CARD HIT: id={d}:{d} at ({d:.0}, {d:.0})\n", .{
                card_id.index,
                card_id.generation,
                pos.x,
                pos.y,
            });
            return Command{ .play_card = .{ .card_id = card_id } };
        }

        // Hit test enemies (for targeting)
        if (self.hitTestEnemies(pos)) |target_id| {
            std.debug.print("ENEMY HIT: id={d}:{d}\n", .{ target_id.index, target_id.generation });
            return Command{ .select_target = .{ .target_id = target_id } };
        }

        std.debug.print("CLICK MISS at ({d:.0}, {d:.0})\n", .{ pos.x, pos.y });
        return null;
    }

    fn handleKey(self: *CombatView, keycode: Keycode) ?Command {
        _ = self;
        // Space/Enter to end turn, Escape to cancel, etc.
        switch (keycode) {
            .q => {
                std.process.exit(0);
            },
            .space => return Command{ .end_turn = {} },
            else => return null,
        }
    }

    // Hit testing - recomputes layout on demand

    fn hitTestHand(self: *CombatView, pos: Point) ?ID {
        const hand = self.playerHand();

        for (hand, 0..) |card, i| {
            const card_x = hand_layout.start_x + @as(f32, @floatFromInt(i)) * hand_layout.spacing;
            const card_rect = Rect{
                .x = card_x,
                .y = hand_layout.y,
                .w = hand_layout.card_width,
                .h = hand_layout.card_height,
            };
            if (card_rect.pointIn(pos)) {
                return toCommandID(card.id);
            }
        }
        return null;
    }

    fn hitTestEnemies(self: *CombatView, pos: Point) ?ID {
        const enemy_list = self.enemies();
        const enemy_width: f32 = 80;
        const enemy_height: f32 = 120;
        const enemy_y: f32 = 100;
        const start_x: f32 = 300;
        const spacing: f32 = 120;

        for (enemy_list, 0..) |enemy, i| {
            const enemy_x = start_x + @as(f32, @floatFromInt(i)) * spacing;
            if (pos.x >= enemy_x and pos.x < enemy_x + enemy_width and
                pos.y >= enemy_y and pos.y < enemy_y + enemy_height)
            {
                return toCommandID(enemy.id);
            }
        }
        return null;
    }

    // Convert domain entity.ID to commands.ID
    fn toCommandID(eid: @import("../../domain/entity.zig").ID) ID {
        return .{ .index = eid.index, .generation = eid.generation };
    }

    // Rendering - layout constants (shared with hit testing)

    const hand_layout = struct {
        const card_width: f32 = card_renderer.CARD_WIDTH;
        const card_height: f32 = card_renderer.CARD_HEIGHT;
        const y: f32 = 400; // bottom area
        const start_x: f32 = 100;
        const spacing: f32 = card_width + 10;
    };

    pub fn renderables(self: *const CombatView, alloc: std.mem.Allocator) !std.ArrayList(Renderable) {
        var list = try std.ArrayList(Renderable).initCapacity(alloc, 32);

        // Debug: dark background to show combat view is active
        try list.append(alloc, .{
            .filled_rect = .{
                .rect = .{ .x = 0, .y = 0, .w = 800, .h = 600 },
                .color = .{ .r = 20, .g = 25, .b = 30, .a = 255 },
            },
        });

        // Player hand
        const hand = self.playerHand();
        for (hand, 0..) |card, i| {
            const x = hand_layout.start_x + @as(f32, @floatFromInt(i)) * hand_layout.spacing;

            const card_vm = CardViewModel.fromInstance(card.*, .{});

            try list.append(alloc, .{
                .card = .{
                    .model = card_vm,
                    .dst = Rect{
                        .x = x,
                        .y = hand_layout.y,
                        .w = hand_layout.card_width,
                        .h = hand_layout.card_height,
                    },
                },
            });
        }

        // TODO: enemies (top area)
        // TODO: engagement info / advantage bars
        // TODO: stamina/time indicators
        // TODO: phase indicator

        return list;
    }
};
