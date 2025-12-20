const std = @import("std");
const lib = @import("infra");
const config = lib.config;
const rect = lib.sdl.rect;
// const zigfsm = lib.zigfsm;
const zigfsm = @import("zigfsm");

const body = @import("body.zig");
const player = @import("player.zig");
const random = @import("random.zig");
const Player = player.Player;
const events = @import("events.zig");
const EventSystem = events.EventSystem;
const Event = events.Event;

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

pub const Encounter = struct {};

pub const World = struct {
    alloc: std.mem.Allocator,
    events: EventSystem,
    encounter: ?Encounter,
    random: random.RandomStreamDict,
    player: Player,
    fsm: zigfsm.StateMachine(GameState, GameEvent, .wait_for_player),

    pub fn init(alloc: std.mem.Allocator) !@This() {
        var fsm = zigfsm.StateMachine(GameState, GameEvent, .wait_for_player).init();

        try fsm.addEventAndTransition(.start_game, .menu, .wait_for_player);
        try fsm.addEventAndTransition(.end_player_turn, .wait_for_player, .wait_for_ai);
        try fsm.addEventAndTransition(.begin_animation, .wait_for_ai, .animating);
        try fsm.addEventAndTransition(.end_animation, .animating, .wait_for_player);

        return @This(){
            .alloc = alloc,
            .events = try EventSystem.init(alloc),
            .encounter = null,
            .random = random.RandomStreamDict.init(),
            .player = Player.init(),
            .fsm = fsm,
        };
    }

    pub fn deinit(self: *World, alloc: std.mem.Allocator) void {
        _ = .{ self, alloc };
        self.events.deinit();
    }

    pub fn step(self: *World) void {
        _ = .{self};
        //
    }
};
