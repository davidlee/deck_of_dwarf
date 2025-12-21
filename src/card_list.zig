const std = @import("std");
const Event = @import("events.zig").Event;
const EntityID = @import("entity.zig").EntityID;

const cards = @import("cards.zig");

const Rule = cards.Rule;
const TagSet = cards.TagSet;
const Cost = cards.Cost;
const Trigger = cards.Trigger;
const Effect = cards.Effect;
const Expression = cards.Expression;
const Technique = cards.Technique;

var template_id: cards.ID = 0;
var technique_id: cards.ID = 0;

// ID helpers
fn nextID(comptime currID: *cards.ID) cards.ID {
    currID.* += 1;
    return currID;
}

fn hashName(comptime name: []const u8) u64 {
    return std.hash.Wyhash.hash(0, name);
}

const TechniqueRepository = struct {
    entries: TechniqueEntries,

    fn byName(comptime name: []const u8) Technique {
        const target = hashName(name);
        inline for (TechniqueEntries) |tech| {
            if (tech.id == target) return tech;
        }
        @compileError("unknown technique: " ++ name);
    }
};

const TechniqueEntries = []Technique{
    Technique{
        .id = hashName("thrust"), 
        .name = "thrust",
        .damage = .{
            .instances = .{ .amount = 1.0, .types = .{.pierce} },
            .scaling = .{
                .ratio = 0.3,
                .stats = .{ .speed, .power },
            },
        },
        .deflect = 1.3,
        .dodge = 0.5,
        .counter = 1.1,
        .parry = 1.2,
    },
};


pub const Techniques: TechniqueRepository = .{
    .entries = TechniqueEntries,
};

pub const BeginnerDeck: []cards.Template = .{
    .{
        .id = nextID(&template_id),
        .kind = .action,
        .name = "thrust",
        .description = "hit them with the pokey bit",
        .rarity = .common,
        .tags = TagSet{
            .melee = true,
            .offensive = true,
        },
        .rules = Rule{
            .trigger = .on_play,
            .valid = .always,
            .expressions = .{.{
                .effect = .{
                    .combat_technique = hashName("thrust"),
                },
            }},
        },
        .cost = Cost{ .stamina = 3.0, .time = 0.3 },
    },

    cards.Template{
        .id = nextID(&template_id),
        .kind = .action,
        .name = "block",
        .description = "defend",
        .rarity = .common,
        .tags = TagSet{
            .melee = true,
            .defensive = true,
        },
        .rules = Rule{},
        .cost = Cost{ .stamina = 2.0, .time = 0.3 },
    },
};
