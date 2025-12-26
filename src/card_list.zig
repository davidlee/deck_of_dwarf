const std = @import("std");
const Event = @import("events.zig").Event;

const body = @import("body.zig");
const cards = @import("cards.zig");
const combat = @import("combat.zig");
const damage = @import("damage.zig");
const stats = @import("stats.zig");

const Rule = cards.Rule;
const TagSet = cards.TagSet;
const Cost = cards.Cost;
const Trigger = cards.Trigger;
const Effect = cards.Effect;
const Template = cards.Template;
const Expression = cards.Expression;
const Technique = cards.Technique;
const TechniqueID = cards.TechniqueID;

const ID = cards.ID;

fn hashName(comptime name: []const u8) ID {
    return std.hash.Wyhash.hash(0, name);
}

const TechniqueRepository = struct {
    entries: []Technique,
};

pub const TechniqueEntries = [_]Technique{
    .{
        .id = .thrust,
        .name = "thrust",
        .target_height = .mid, // thrusts target center mass
        .damage = .{
            .instances = &.{
                .{ .amount = 1.0, .types = &.{.pierce} },
            },
            .scaling = .{
                .ratio = 0.5,
                .stats = .{ .average = .{ .speed, .power } },
            },
        },
        .difficulty = 0.7,
        .deflect_mult = 1.3,
        .dodge_mult = 0.5,
        .counter_mult = 1.1,
        .parry_mult = 1.2,
    },

    .{
        .id = .swing,
        .name = "swing",
        .target_height = .high, // swings come from above
        .secondary_height = .mid, // can catch torso too
        .damage = .{
            .instances = &.{
                .{ .amount = 1.0, .types = &.{.slash} },
            },
            .scaling = .{
                .ratio = 1.2,
                .stats = .{ .average = .{ .speed, .power } },
            },
        },
        .difficulty = 1.0,
        .deflect_mult = 1.0,
        .dodge_mult = 1.2,
        .counter_mult = 1.3,
        .parry_mult = 1.2,
    },

    // Feint: deceptive attack that gains control advantage
    // Low damage but excellent for setting up follow-ups
    .{
        .id = .feint,
        .name = "feint",
        .target_height = .high, // feints typically threaten high
        .damage = .{
            .instances = &.{.{ .amount = 0.3, .types = &.{.slash} }},
            .scaling = .{
                .ratio = 0.3,
                .stats = .{ .stat = .speed },
            },
        },
        .difficulty = 0.3, // easy to execute
        .deflect_mult = 0.7, // hard to deflect (deceptive)
        .dodge_mult = 1.3, // easy to dodge (not committed)
        .counter_mult = 0.5, // very hard to counter
        .parry_mult = 0.8, // hard to parry
        // Feint-specific advantage: big control gain, minimal miss penalty
        .advantage = .{
            .on_hit = .{
                .pressure = 0.05, // low pressure (not threatening)
                .control = 0.25, // high control gain (initiative)
            },
            .on_miss = .{
                .control = -0.05, // minimal penalty (was never committed)
                .self_balance = -0.02,
            },
        },
    },

    // Defensive techniques - guard positions
    .{
        .id = .deflect,
        .name = "deflect",
        .guard_height = .mid, // mid guard, covers adjacent
        .covers_adjacent = true,
        .damage = .{
            .instances = &.{.{ .amount = 0.0, .types = &.{} }},
            .scaling = .{
                .ratio = 0.0,
                .stats = .{ .stat = .power },
            },
        },
        .difficulty = 1.0,
        .deflect_mult = 1.0,
        .dodge_mult = 1.0,
        .counter_mult = 1.0,
        .parry_mult = 1.0,
    },

    .{
        .id = .parry,
        .name = "parry",
        .guard_height = .high, // high parry
        .covers_adjacent = false,
        .damage = .{
            .instances = &.{.{ .amount = 0.0, .types = &.{} }},
            .scaling = .{
                .ratio = 0.0,
                .stats = .{ .stat = .power },
            },
        },
        .difficulty = 1.0,
        .deflect_mult = 1.0,
        .dodge_mult = 1.0,
        .counter_mult = 1.0,
        .parry_mult = 1.0,
    },

    .{
        .id = .block,
        .name = "block",
        .guard_height = .mid, // shield covers mid
        .covers_adjacent = true, // shields cover wide area
        .damage = .{
            .instances = &.{.{ .amount = 0.0, .types = &.{} }},
            .scaling = .{
                .ratio = 0.0,
                .stats = .{ .stat = .power },
            },
        },
        .difficulty = 1.0,
        .deflect_mult = 1.0,
        .dodge_mult = 1.0,
        .counter_mult = 1.0,
        .parry_mult = 1.0,
    },
};

// -----------------------------------------------------------------------------
// Template helpers
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Starter deck
// -----------------------------------------------------------------------------
const templates = [_]Template{
    t_thrust,
    t_slash,
    t_shield_block,
};

pub const BeginnerDeck = blk: {
    var output: [templates.len]Template = undefined;
    for (templates, 0..) |data, idx| {
        const template: Template = .{
            .id = idx,
            .name = data.name,
            .kind = data.kind,
            .description = data.description,
            .rarity = data.rarity,
            .cost = data.cost,
            .tags = data.tags,
            .rules = data.rules,
        };
        output[idx] = template;
    }
    break :blk output;
};

const t_thrust = Template{
    .id = 0,
    .kind = .action,
    .name = "thrust",
    .description = "hit them with the pokey bit",
    .rarity = .common,
    .cost = .{ .stamina = 3.0, .time = 0.2 },
    .tags = .{ .melee = true, .offensive = true },
    .rules = &.{
        .{
            .trigger = .on_play,
            .valid = .always,
            .expressions = &.{.{
                .effect = .{
                    .combat_technique = Technique.byID(.thrust),
                },
                .filter = null,
                .target = .all_enemies,
            }},
        },
    },
};

const t_slash = Template{
    .id = 0,
    .kind = .action,
    .name = "slash",
    .description = "slash them like a pirate",
    .rarity = .common,
    .cost = .{ .stamina = 3.0, .time = 0.3 },
    .tags = .{ .melee = true, .offensive = true },
    .rules = &.{
        .{
            .trigger = .on_play,
            .valid = .always,
            .expressions = &.{.{
                .effect = .{
                    .combat_technique = Technique.byID(.swing),
                },
                .filter = null,
                .target = .all_enemies,
            }},
        },
    },
};

const t_shield_block = Template{
    .id = 0,
    .kind = .action,
    .name = "shield block",
    .description = "shields were made to be splintered",
    .rarity = .common,
    .cost = .{ .stamina = 2.0, .time = 0.3 },
    .tags = .{ .melee = true, .defensive = true },
    .rules = &.{
        .{
            .trigger = .on_play,
            .valid = .always,
            .expressions = &.{.{
                .effect = .{
                    .combat_technique = Technique.byID(.block),
                },
                .filter = null,
                .target = .self,
            }},
        },
    },
};
