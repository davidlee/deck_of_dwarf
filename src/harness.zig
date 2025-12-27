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
const weapon = @import("weapon.zig");
const weapon_list = @import("weapon_list.zig");

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

    log("draw time: {}\n", .{world.player.weapons});

    const mobdeck = try Deck.init(world.alloc, &BeginnerDeck);
    var buckler = try world.alloc.create(weapon.Instance);
    buckler.id = try world.entities.weapons.insert(buckler);
    buckler.template = weapon_list.byName("buckler");

    var mob = try combat.Agent.init(
        world.alloc,
        world.entities.agents,
        .ai,
        combat.Strat{ .deck = mobdeck },
        stats.Block.splat(6),
        try body.Body.init(world.alloc),
        10.0,
        combat.Armament{ .single = buckler },
    );

    log("ok: {}\n", .{mob});
    try world.encounter.?.enemies.append(world.alloc, mob);

    log("ready: {}\n", .{world.encounter.?.enemies.items[0]});

    // draw some cards - only player has a "real" deck
    // we should prolly move this into an event listener in apply which runs whenever we ender the .draw_cards state ..
    for(0..8) |_| {
        try world.player.cards.deck.move(world.player.cards.deck.draw.items[0].id, .draw , .hand);
    }
    
    try world.commandHandler.gameStateTransition(.player_card_selection);
    try nextFrame(world);

    mob.body = mob.body; // shh no const warning
    
    // this mob just has a pool, not a real deck ...
    // 
    // try mob.cards.deck.move(mob.cards.deck.hand.items[0].id, .hand, .in_play);
    // try mob.cards.deck.move(mob.cards.deck.hand.items[0].id, .hand, .in_play);
    // try mob.cards.deck.move(mob.cards.deck.hand.items[0].id, .hand, .in_play);

    // try nextFrame(world);

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

    // try nextFrame(world);

    try world.commandHandler.gameStateTransition(.tick_resolution);
    
    const result = try world.processTick();
    
    log("tick resolved: {any}\n", .{result});
    
    try nextFrame(world); // process resolution events
    
    for (world.player.cards.deck.in_play.items) |inst| log("player card: {s}\n", .{inst.template.name});

    // try nextFrame(world);

    std.process.exit(0);
}

fn nextFrame(world: *World) !void {
    world.events.swap_buffers();
    try world.step(); // let's see that event;

    std.debug.print("tick ... current_state: {}\n", .{world.fsm.currentState()});
}
