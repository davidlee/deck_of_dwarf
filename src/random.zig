const std = @import("std");

const lib = @import("infra");
const World = @import("world.zig").World;
const events = @import("events.zig");
const EventSystem = events.EventSystem;
const Event = events.Event;

const Stream = struct {
    seed: u64,
    rng: std.Random,

    fn init() @This() {
        var seed: u64 = undefined;
        std.crypto.random.bytes(std.mem.asBytes(&seed));

        var prng = std.Random.DefaultPrng.init(seed);
        const rng = prng.random(); // Get the random number generator interface

        return Stream{
            .seed = seed,
            .rng = rng,
        };
    }
};

pub const RandomStreamID = enum {
    combat,
    deck_builder,
    shuffler,
    effects,
};

pub const RandomStreamDict = struct {
    combat: Stream,
    deck_builder: Stream,
    shuffler: Stream,
    effects: Stream,

    pub fn init() @This() {
        return @This(){
            .combat = Stream.init(),
            .deck_builder = Stream.init(),
            .shuffler = Stream.init(),
            .effects = Stream.init(),
        };
    }

    fn get(self: *RandomStreamDict, id: RandomStreamID) !lib.random.Stream {
        return switch (id) {
            RandomStreamID.combat => self.combat,
            RandomStreamID.deck_builder => self.deck_builder,
            RandomStreamID.shuffler => self.shuffler,
            RandomStreamID.effects => self.effects,
            else => unreachable,
        };
    }

    pub fn drawRandom(self: *RandomStreamDict, world: *World, id: RandomStreamID) !f32 {
        var stream = try self.get(id);
        const r = stream.rng.float(f32);
        try world.events.push(Event{ .draw_random = .{ .stream = id, .result = r } });
        return r;
    }
};
