const std = @import("std");
const DamageKind = @import("damage.zig").Kind;

pub const PartIndex = u16; // Up to 65k body parts is enough
pub const NO_PARENT = std.math.maxInt(PartIndex);

pub const Tag = enum {
    // Human exterior bits
    head,
    eye,
    nose,
    ear,
    neck,
    torso,
    abdomen,
    shoulder,
    groin,
    arm,
    elbow,
    forearm,
    wrist,
    hand,
    finger,
    thumb,
    thigh,
    knee,
    shin,
    ankle,
    foot,
    toe,
    // human organs
    brain,
    heart,
    lung,
    stomach,
    liver,
    intestine,
    tongue,
    trachea,
    spleen,
    // // Human bones
    // Skull,
    // Tooth,
    // Jaw,
    // Vertebrate,
    // Ribcage,
    // Pelvis,
    // Femur,
    // Tibia,
    //
    // Other creature bits ...
};

pub const Side = enum(u8) { left, right, center, none };

pub const TissueLayer = enum { bone, artery, muscle, fat, nerve, skin };

pub const Part = struct {
    name_hash: u32, // e.g. hash("left_index_finger") for lookups
    def_id: u16,
    tag: Tag,
    parent: ?PartIndex, // Index of the body part this is attached to

    integrity: f32, // destroyed at 0.0
    wounds: std.ArrayList(Wound),
    is_severed: bool, // If true, all children are implicitly disconnected

    // FIXME: performantly look up PartDef flags before checking condition
    // must we also check parent isn't severed?
    fn can_grasp(self: *Part) bool {
        self.integrity > 0.6;
    }

    fn can_support_weight(self: *Part) bool {
        self.integrity > 0.3;
    }

    fn can_walk(self: *Part) bool {
        self.integrity > 0.4;
    }

    fn can_run(self: *Part) bool {
        self.integrity > 0.8;
    }

    fn can_write(self: *Part) bool {
        self.integrity > 0.8;
    }

    // durability: f32, // an abstraction of density, circumference & hardness. Influenced by species + individual traits.
    // armour: precompute protective layers
};

pub const PartId = struct {
    hash: u64,
    pub fn init(comptime name: []const u8) PartId {
        return .{ .hash = std.hash.Wyhash.hash(0, name) };
    }
};

pub const PartDef = struct {
    id: PartId,
    parent: ?PartId,
    tag: Tag,
    side: Side,
    name: []const u8,
    base_hit_chance: f32,
    base_durability: f32,
    trauma_mult: f32,
    flags: packed struct {
        is_vital: bool = false,
        is_internal: bool = false,
        can_grasp: bool = false,
        can_stand: bool = false,
        can_see: bool = false,
        can_hear: bool = false,
    } = .{},
};

pub const Body = struct {
    parts: std.ArrayList(Part),

    // Helper to find things
    pub fn get_children(self: Body, parent: PartIndex) std.Iterator {
        _ = .{ self, parent };
        // TODO: implement
    }
};

pub const Wound = struct {
    tissue: TissueLayer,
    severity: f32, // 0.0 to 1.0 (Severed / Crushed)
    type: DamageKind,
    // dressing
    // infection
};

// An array of nodes defining the topology
fn definePart(
    comptime name: []const u8,
    tag: Tag,
    side: Side,
    comptime parent_name: ?[]const u8,
) PartDef {
    return .{
        .id = PartId.init(name),
        .parent = if (parent_name) |p| PartId.init(p) else null,
        .tag = tag,
        .side = side,
        .name = name,
        .base_hit_chance = 1.0,
        .base_durability = 1.0,
        .trauma_mult = 1.0,
    };
}

pub const HumanoidPlan = [_]PartDef{
    definePart("torso", .torso, .Center, null),
    definePart("head", .head, .center, "torso"),
    definePart("neck", .neck, .center, "torso"),
    // ...
};
