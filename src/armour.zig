const body = @import("body.zig");
const damage = @import("damage.zig");
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
    // kitchen utensils - finding weak spots is a real challenge.
    indimidating,
    // a practical compromise, but with attention paid to the back and kidneys, calves, etc.
    comprehensive,
    // most of the bits that might get hit - as long as you're facing the right way.
    frontal,
    // concerningly optimistic, e.g. a miserly panel over the vitals
    minimal,
};

const Fit = struct {

    // coverage: []
};

const ConstructionLayer = struct {
    material: Material,
    coverage: inventory.Coverage,
    layer: inventory.Layer,
};

// pub const Layer = struct {
//     part_tags: []const body.PartTag,
//     layer: inventory.Layer,
//     material: Material,
//     totality: Totality,
// };

const Construction = struct {
    name: []const u8,
    // layers: Layer,
};

// all armour as worn, with precomputed values
pub const Stack = struct {};
