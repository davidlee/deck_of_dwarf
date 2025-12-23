const std = @import("std");
const stats = @import("stats.zig");
const deck = @import("deck.zig");
const body = @import("body.zig");
const combat = @import("combat.zig");

pub fn newPlayer(
    alloc: std.mem.Allocator,
    playerDeck: deck.Deck,
    sb: stats.Block,
    bd: body.Body,
) !combat.Agent {
    return try combat.Agent.init(alloc, .player, combat.Strat{ .deck = playerDeck }, sb, bd, 10.0);
}
