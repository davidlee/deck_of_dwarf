const std = @import("std");

const armour = @import("armour.zig");
const weapon = @import("weapon.zig");
const combatant = @import("combatant.zig");
const damage = @import("damage.zig");
const stats = @import("stats.zig");
const body = @import("body.zig");
const deck = @import("deck.zig");
const cards = @import("cards.zig");

const Director = enum {
    player,
    ai,
};

const Resources = struct {
    alloc: std.mem.Allocator,
    director: Director,
    cards: Strat,

    stamina: f32,
    stamina_available: f32,
    time_available: f32 = 1.0,

    state: combatant.State,
    engagement: ?combatant.Engagement,

    // may be humanoid, or not
    body: body.Body,

    // sourced from cards.equipped
    armour: armour.Stack,
    weapons: Armament,

    conditions: std.ArrayList(damage.Condition),
    immunities: std.ArrayList(damage.Immunity),
    resistances: std.ArrayList(damage.Resistance),
    vulnerabilities: std.ArrayList(damage.Vulnerability),
};

const Armament = union(enum) {
    single: weapon.Instance,
    dual: struct {
        primary: weapon.Instance,
        secondary: weapon.Instance,
    },
    compound: [][]weapon.Instance,
};

const Strat = union(enum) {
    deck: deck.Deck,
    // script: BehaviourScript,
    pool: TechniquePool,
};

// Humanoid AI: simplified pool
const TechniquePool = struct {
    available: []const *cards.Template, // what they know
    in_play: std.ArrayList(*cards.Instance), // committed this tick
    cooldowns: std.AutoHashMap(cards.ID, u8), // technique -> ticks remaining

    // No hand/draw - AI picks from available based on behavior pattern
    pub fn canUse(self: *const TechniquePool, t: *const cards.Template) bool {
        return (self.cooldowns.get(t.id) orelse 0) == 0;
    }
};

// const ScriptedAction = struct {};
//
// // Creature: pure behavior script, no "cards" at all
// const BehaviourScript = struct {
//     pattern: []const ScriptedAction,
//     index: usize,
//
//     pub fn next(self: *BehaviourScript) ScriptedAction {
//         const action = self.pattern[self.index];
//         self.index = (self.index + 1) % self.pattern.len;
//         return action;
//     }
// };
