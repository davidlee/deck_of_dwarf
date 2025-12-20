const std = @import("std");
const ps = @import("polystate");
const fsm = @import("zigfsm");
const rect = @import("sdl3").rect;

const Config = struct {
    fps: usize,
    width: usize,
    height: usize,

    fn init() @This() {
        return @This(){
            .fps = 60,
            .width = 1080,
            .height = 860,
        };
    }
};

const UIState = struct {
    zoom: f32,
    screen: rect.IRect,
    camera: rect.IRect,
    mouse: rect.FPoint,
    fn init() @This() {
        return @This(){
            .zoom = 1.0,
            .screen = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
            .camera = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
            .mouse = .{ .x = 0, .y = 0 },
        };
    }
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
};

// Dorsal Symmetry
pub const Side = enum { Left, Right };
pub const HumanoidBodyPart = enum { Head, Neck, Chest };

pub const Wound = struct {};

pub const Player = struct {};

pub const World = struct {
    config: Config,
    ui: UIState,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !@This() {
        return @This(){
            .alloc = alloc,
            .config = Config.init(),
            .ui = UIState.init(),
        };
    }

    pub fn deinit(self: *World, alloc: std.mem.Allocator) void {
        _ = .{ self, alloc };
    }
};
