const std = @import("std");
const lib = @import("infra");
const config = lib.config;
const rect = lib.sdl.rect;
const fsm = lib.fsm;

const body = @import("body.zig");

pub const Archetype = .{
    .soldier = StatBlock{
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
    .hunter = StatBlock{
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

pub const StatBlock = packed struct {
    // physical
    power: f32,
    speed: f32,
    agility: f32,
    dexterity: f32,
    fortitude: f32,
    endurance: f32,
    // mental
    acuity: f32,
    will: f32,
    intuition: f32,
    presence: f32,

    fn splat(num: f32) StatBlock {
        return StatBlock{
            .power = num,
            .speed = num,
            .agility = num,
            .dexterity = num,
            .fortitude = num,
            .endurance = num,
            // mental
            .acuity = num,
            .will = num,
            .intuition = num,
            .presence = num,
        };
    }

    pub fn init(template: StatBlock) StatBlock {
        const s = StatBlock{};
        s.* = template;
        return s;
    }
};

pub const Player = struct {
    stats: StatBlock,
    wounds: void,
    conditions: void,

    pub fn init() Player {
        return Player{ .stats = StatBlock.splat(5), .wounds = {}, .conditions = {} };
    }
};
