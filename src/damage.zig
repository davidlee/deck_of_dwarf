const std = @import("std");
const lib = @import("infra");
const PartTag = @import("body.zig").PartTag;
const Scaling = @import("stats.zig").Scaling;

const Immunity = union(enum) {
    condition: Condition,
    damage: Kind,
    // dot_effect
    // magic / etc
};

const Resistance = struct {
    damage: Kind,

    threshold: f32, // no damage below this number
    ratio: f32, // multiplier for remainder
};

const Vulnerability = struct {
    damage: Kind,
    ratio: f32,
    // maybe: threshold -> trigger (DoT / Effect / Special ..)
};

const Susceptibility = struct {
    condition: Condition,
    // trigger: null, // TODO:
};

pub const TemporaryCondition = struct {
    condition: Condition,
    time_remaining: f32,
    // todo: conditions like recovering stamina / advantage, etc
    // random chance per tick
    // on_remove: null,  // TODO: function - check for sepsis, apply lesser condition, etc
};

// pub const Trigger = union(enum) { };

// DoT are separate
//
pub const Condition = enum {
    blinded,
    deafened,
    silenced,
    stunned,
    paralysed,
    confused,
    prone,
    winded,
    shaken,
    fearful,
    nauseous,
    surprised,
    unconscious,
    comatose,
    asphyxiating, // Open question: not DoT because the intensity is creature specific, not part of the effect
    starving,
    dehydrating,
    exhausted,
};

pub const DoTEffect = union(enum) {
    bleeding: f32,
    burning: f32,
    freezing: f32,
    corroding: f32,
    diseased: f32, // probably needs modelling
    poisoned: f32, // probably needs modelling
};

pub const Kind = enum {
    // physical
    bludgeon,
    pierce,
    slash,
    crush,
    shatter,

    // elemental
    fire,
    frost,
    lightning,
    corrosion,

    // energy
    beam,
    plasma,
    radiation,

    // biological
    asphyxiation,
    starvation,
    dehydration,
    infection,
    necrosis,

    // magical
    arcane,
    divine,
    death,
    disintegration,
    transmutation,
    channeling,
    binding,

    fn isPhysical(self: *Kind) bool {
        return self.kind() == .physical;
    }

    fn isMagical(self: *Kind) bool {
        return self.kind() == .magical;
    }

    fn isElemental(self: *Kind) bool {
        return self.kind() == .elemental;
    }

    fn isBiological(self: *Kind) bool {
        return self.kind() == .biological;
    }

    fn kind(self: *Kind) Category {
        return switch (self) {
            .bludgeon....shatter => .physical,
            .fire....corrosion => .elemental,
            .asphyxiation....necrosis => .biological,
            .arcane....binding => .magical,
        };
    }
};

pub const Instance = struct {
    amount: f32,
    types: []const Kind,
};

pub const Base = struct {
    instances: []const Instance,
    scaling: Scaling,
};

pub const Category = enum {
    physical,
    elemental,
    energy,
    biogogical,
    magical,
};

test "Kind" {}
