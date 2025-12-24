const std = @import("std");
const body = @import("body.zig");
const damage = @import("damage.zig");
const entity = @import("entity.zig");
const inventory = @import("inventory.zig");

const Resistance = damage.Resistance;
const Vulnerability = damage.Vulnerability;

const Quality = enum {
    terrible,
    poor,
    common,
    excellent,
    masterwork,
};

const Material = struct {
    name: []const u8,

    // these modify to the wearer
    resistances: []Resistance,
    vulnerabilities: []Vulnerability,

    // these modify to the material itself
    self_resistances: []Resistance,
    self_vulnerabilities: []Vulnerability,

    quality: Quality,
    durability: f32, // base - modified by size, quality, etc
};

// coverage of a particular part by a particular material - or,
// how hard is it to get around the tough stuff with a lucky stab or a shiv in the kidneys?
const Totality = enum {
    // full-fit simple construction (gambeson, etc) with no secondary materials
    total,
    // as good as it gets. More fully articulated plates than a pixar film about anthropomorphic
    // kitchen utensils - only visor slits, armpits, etc admit any entry.
    indimidating,
    // a practical compromise, but with attention paid to the back and kidneys, calves, etc.
    comprehensive,
    // most of the bits that might get hit - as long as you're facing the right way.
    frontal,
    // concerningly optimistic, e.g. a miserly panel over the vitals
    minimal,
};

const InstanceCoverage = struct {
    totality: Totality,
    part_tag: body.PartTag,
    layer: inventory.Layer,
    material: *const Material,
    tags: null,
};

const PatternCoverage = struct { // as per inventory.Coverage but includes Totality
    totality: Totality,
    part_tags: []const body.PartTag,
    layer: inventory.Layer,
};

const Pattern = struct {
    coverage: []PatternCoverage,
};

// designed to be easily definable at comptime
const Template = struct {
    id: u64,
    name: []const u8,
    material: *const Material,
    pattern: *const Pattern,
};

const Instance = struct {
    name: []const u8,
    template_id: u64,
    id: entity.ID,
    tags: null,
    locations: []LocationCoverage,

    pub fn init(alloc: std.mem.Allocator, template: *const Template) !*Instance {
        _ = .{ template, alloc };
        // unpack the template into []InstanceCoverage for ergonomic runtime access
    }

    pub fn deinit(self: *Instance, alloc: std.mem.Allocator) void {
        _ = .{ self, alloc };
    }
};

// all armour as worn, with precomputed values
pub const Stack = struct {
    // Precomputed per-part protection
    // Key: hash(PartTag, Side) or PartIndex
    // Value: array of LayerProtection (one per layer present)
    coverage: std.AutoHashMap(u32, [9]?LayerProtection),

    const LayerProtection = struct {
        material: *const Material,
        totality: Totality,
        integrity: f32, // current durability of this piece
    };

    pub fn getProtection(self: *const Stack, part: body.PartTag, side: body.Side) []const LayerProtection {
        _ = .{ self, part, body, side };
        // return layers covering this part, outer to inner
    }
};
