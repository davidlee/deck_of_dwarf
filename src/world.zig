const std = @import("std");
const lib = @import("infra");
const zigfsm = @import("zigfsm");
const player = @import("player.zig");
const random = @import("random.zig");
const events = @import("events.zig");
const apply = @import("apply.zig");
const cards = @import("cards.zig");
const card_list = @import("card_list.zig");

const EventSystem = events.EventSystem;
const CommandHandler = apply.CommandHandler;
const EventProcessor = apply.EventProcessor;
const Event = events.Event;
const SlotMap = @import("slot_map.zig").SlotMap;
const Mob = @import("mob.zig").Mob;
const Deck = @import("deck.zig").Deck;
const Player = player.Player;
const BeginnerDeck = card_list.BeginnerDeck;

const GameEvent = enum {
    start_game,
    end_player_turn,
    begin_animation,
    end_animation,
};

const GameState = enum {
    menu,
    wait_for_player,
    wait_for_ai,
    animating,
};

pub const Encounter = struct {
    enemies: std.ArrayList(*Mob),
    //
    // environment ...
    // loot ...
    //
    fn init(alloc: std.mem.Allocator) !Encounter {
        var e = Encounter{
            .enemies = try std.ArrayList(*Mob).initCapacity(alloc, 5),
        };
        var mob = try alloc.create(Mob);
        mob.wounds = 0.0;

        try e.enemies.append(alloc, mob);
        return e;
    }

    fn deinit(self: *Encounter, alloc: std.mem.Allocator) void {
        for (self.enemies.items) |nme| alloc.destroy(nme);
        self.enemies.deinit(alloc);
    }
};

pub const World = struct {
    alloc: std.mem.Allocator,
    events: EventSystem,
    encounter: ?Encounter,
    random: random.RandomStreamDict,
    player: Player,
    fsm: zigfsm.StateMachine(GameState, GameEvent, .wait_for_player),
    deck: Deck,
    commandHandler: CommandHandler,
    eventProcessor: EventProcessor,

    pub fn init(alloc: std.mem.Allocator) !*World {
        var fsm = zigfsm.StateMachine(GameState, GameEvent, .wait_for_player).init();

        try fsm.addEventAndTransition(.start_game, .menu, .wait_for_player);
        try fsm.addEventAndTransition(.end_player_turn, .wait_for_player, .wait_for_ai);
        try fsm.addEventAndTransition(.begin_animation, .wait_for_ai, .animating);
        try fsm.addEventAndTransition(.end_animation, .animating, .wait_for_player);

        const self = try alloc.create(World);
        self.* = .{
            .alloc = alloc,
            .events = try EventSystem.init(alloc),
            .encounter = try Encounter.init(alloc),
            .random = random.RandomStreamDict.init(),
            .player = try Player.init(alloc),
            .fsm = fsm,
            .deck = try Deck.init(alloc, &BeginnerDeck),
            .eventProcessor = EventProcessor.init(self),
            .commandHandler = CommandHandler.init(self),
        };
        return self;
    }

    pub fn deinit(self: *World) void {
        self.events.deinit();
        self.deck.deinit();
        self.player.deinit();
        if (self.encounter) |*encounter| {
            encounter.deinit(self.alloc);
        }
        self.alloc.destroy(self);
    }

    pub fn step(self: *World) void {
        while (try self.eventProcessor.dispatchEvent(&self.events)) {
            // std.debug.print("processed events:\n", .{});
        }
    }

    pub fn drawRandom(self: *World, id: random.RandomStreamID) !f32 {
        const r = self.random.get(id).random().float(f32);
        try self.events.push(.{ .draw_random = .{ .stream = id, .result = r } });
        return r;
    }
};
