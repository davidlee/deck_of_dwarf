const std = @import("std");
const lib = @import("infra");
const Event = @import("events.zig").Event;
const EventTag = std.meta.Tag(Event);

const EntityID = @import("entity.zig").EntityID;
const damage = @import("damage.zig");
const stats = @import("stats.zig");
const World = @import("world.zig").World;
const Player = @import("player.zig").Player;
const cards = @import("cards.zig");
const card_list = @import("card_list.zig");
const mob = @import("mob.zig");

const Rule = cards.Rule;
const TagSet = cards.TagSet;
const Cost = cards.Cost;
const Trigger = cards.Trigger;
const Effect = cards.Effect;
const Expression = cards.Expression;
const Technique = cards.Technique;

pub const CommandError = error{
    CommandInvalid,
    NotImplemented,
};

const EffectContext = struct {
    card: *cards.Instance,
    effect: *const cards.Effect,
    target: *const cards.TargetQuery,
    actor: Player,
    technique: ?TechniqueContext = null,
};

const TechniqueContext = struct {
    // damage_blueprint: []const damage.Instance,
    // types: []const damage.Kind,
    // actor_stats: stats.Block,
    // equipment: std.ArrayList(*const cards.Instance),
    technique: *const cards.Technique,
    damage: damage.Base,
    actor: *Player, // TODO duck typing
    targets: std.ArrayList(*mob.Mob),

    fn init(dmg: damage.Base, actor: *Player, targets: *std.ArrayList(mob.Mobs)) !TechniqueContext {
        return TechniqueContext{ .damage = dmg, .actor = actor, .targets = targets };
    }
};

pub const CommandHandler = struct {
    world: *World,

    pub fn init(world: *World) @This() {
        return @This(){
            .world = world,
        };
    }

    pub fn playCard(self: *CommandHandler, card: *cards.Instance) !bool {
        // check if it's valid to play
        for (card.template.rules) |rule| {
            // WARN: for now we assume the trigger is fine (caller's responsibility)
            switch (rule.valid) {
                .always => {},
                else => return error.CommandInvalid,
            }
            // TODO: check shared criteria - time / stamina costs, etc
        }
        // if all rules have valid predicates, it must be valid
        // so, for each rule, check predicates, build an EffectContext, and evaluate Expression.filter
        for (card.template.rules) |rule| {
            var active_effects = try std.ArrayList(cards.Effect).initCapacity(self.world.alloc, 0);
            for (rule.expressions) |expr| {
                if (expr.filter) |predicate| {
                    switch (predicate) {
                        .always => {
                            try active_effects.append(self.world.alloc, expr.effect);
                        },
                        else => continue, // NOT IMPLEMENTED YET
                    }
                }

                var ctx = EffectContext{
                    .card = card,
                    .effect = &expr.effect,
                    .actor = self.world.player,
                    .target = &expr.target,
                };
                switch (ctx.effect.*) {
                    .combat_technique => |value| {
                        const tn = self.world.deck.techniques.get(value.name);
                        if (tn) |technique| {
                            ctx.technique = TechniqueContext{
                                .technique = technique,
                                .damage = technique.damage,
                                .actor = &self.world.player,
                                .targets = try std.ArrayList(*mob.Mob).initCapacity(self.world.alloc, 0),
                            };
                        }
                    },
                    else => return CommandError.NotImplemented,
                }
            }
            // run the modifier pipeline for each effect to be applied
            // sink an event for the card
            // sink an event for each effect
            // apply costs / sink more events
        }
        return true;
    }
};

// event -> state mutation
//
// keep the core as:
// State: all authoritative game data
// Command: a player/AI intent (“PlayCard {card_id, target}”)
// Resolver: validates + applies rules
// Event log: what happened (“DamageDealt”, “StatusApplied”, “CardMovedZones”)
// RNG stream: explicit, seeded, reproducible
//
// for:
//
// deterministic replays
// easy undo/redo (event-sourcing or snapshots)
// “what-if” simulations for AI / balance tools
// clean separation from rendering
//
// resolve a command into events, then apply events to state in a predictable way.
