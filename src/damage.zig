const std = @import("std");
// const assert = std.testing.expectEqual
const lib = @import("infra");
const stats = @import("stats.zig");
// const Event = @import("events.zig").Event;
// const EventTag = std.meta.Tag(Event); // std.meta.activeTag(event) for cmp
// const EntityID = @import("entity.zig").EntityID;
pub const BodyPartTag = @import("body.zig").BodyPartTag;

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
    amount: i32,
    types: []const Kind,
};

pub const Packet = struct {
    instances: []const Instance,
};

pub const Category = enum {
    physical,
    elemental,
    energy,
    biogogical,
    magical,
};

pub const ScalingSpec = struct {
    stat: stats.Accessor = .power,
    ratio: f32 = 1.0,
};

test "Kind" {}
