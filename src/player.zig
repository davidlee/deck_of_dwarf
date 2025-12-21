const std = @import("std");
const lib = @import("infra");
const stats = @import("stats.zig");
const config = lib.config;
const rect = lib.sdl.rect;
const fsm = lib.fsm;

const body = @import("body.zig");

pub const Archetype = .{
    .soldier = stats.Template{
        .power = 6,
        .speed = 5,
        .agility = 4,
        .dexterity = 3,
        .fortitude = 6,
        .endurance = 5,
        // mental
        .acuity = 4,
        .will = 4,
        .intuition = 3,
        .presence = 5,
    },
    .hunter = stats.Template{
        .power = 5,
        .speed = 6,
        .agility = 7,
        .dexterity = 3,
        .fortitude = 5,
        .endurance = 5,
        // mental
        .acuity = 6,
        .will = 4,
        .intuition = 4,
        .presence = 4,
    },
};

pub const Player = struct {
    stats: stats.Block,
    wounds: void,
    conditions: void,

    pub fn init() Player {
        return Player{ .stats = stats.Block.splat(5), .wounds = {}, .conditions = {} };
    }
};
