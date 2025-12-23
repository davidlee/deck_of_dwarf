const std = @import("std");
const lib = @import("infra");
const zigfsm = @import("zigfsm");
const player = @import("player.zig");
const random = @import("random.zig");
const events = @import("events.zig");
const apply = @import("apply.zig");
const cards = @import("cards.zig");
const body = @import("body.zig");
const card_list = @import("card_list.zig");
const stats = @import("stats.zig");
const entity = @import("entity.zig");

const EventSystem = events.EventSystem;
const CommandHandler = apply.CommandHandler;
const EventProcessor = apply.EventProcessor;
const Event = events.Event;
const SlotMap = @import("slot_map.zig").SlotMap;
const combat = @import("combat.zig");
const Deck = @import("deck.zig").Deck;
const BeginnerDeck = card_list.BeginnerDeck;
const World = @import("world.zig").World;

const log = std.debug.print;

pub fn runTestCase(world: *World) !void {
    // for (world.deck.allInstances()) |c|
    //     std.debug.print("deck: {any}\n", .{c});

    // perform setup
    // - ensure player has cards
    // currently wired into BeginnerDeck

    // - ensure there's one enemy
    //  - and that it has cards, stats, etc

    // - ensure there's an Encounter
    // - initialise the encounter & player / enemy state

    // log("\nEncounter: {d}\n", .{world.encounter.?.enemies.items.len});
    // log("\nEnemy: {any}\n", .{world.encounter.?.enemies.items[0]});

    const mobdeck = try Deck.init(world.alloc, &BeginnerDeck);

    var mob = try combat.Agent.init(
        world.alloc,
        .ai,
        combat.Strat{ .deck = mobdeck },
        stats.Block.splat(6),
        try body.Body.init(world.alloc),
        10.0,
    );

    try world.encounter.?.enemies.append(world.alloc, &mob);

    try mob.cards.deck.move(mob.cards.deck.hand.items[0].id, .hand, .in_play);
    try mob.cards.deck.move(mob.cards.deck.hand.items[0].id, .hand, .in_play);
    try mob.cards.deck.move(mob.cards.deck.hand.items[0].id, .hand, .in_play);

    try nextFrame(world);

    // play a single action card
    //
    const pd = world.player.cards.deck;
    var card = pd.hand.items[0];
    try world.commandHandler.playActionCard(card);
    log("player stamina: {d}/{d}\n", .{ world.player.stamina, world.player.stamina_available });

    try nextFrame(world);

    card = pd.hand.items[0];
    try world.commandHandler.playActionCard(card);
    log("player stamina: {d}/{d}\n", .{ world.player.stamina, world.player.stamina_available });

    try nextFrame(world);

    card = pd.hand.items[0];
    try world.commandHandler.playActionCard(card);
    log("player stamina: {d}/{d}\n", .{ world.player.stamina, world.player.stamina_available });

    try nextFrame(world);

    try world.commandHandler.gameStateTransition(.player_reaction);
    for (world.player.cards.deck.in_play.items) |inst| log("player card: {s}\n", .{inst.template.name});

    try nextFrame(world);

    std.process.exit(0);
}

fn nextFrame(world: *World) !void {
    world.events.swap_buffers();
    try world.step(); // let's see that event;

    std.debug.print("tick ... current_state: {}\n", .{world.fsm.currentState()});
}
