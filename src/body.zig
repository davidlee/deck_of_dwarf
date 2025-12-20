const std = @import("std");

pub const PartIndex = u16; // Up to 65k body parts is enough
pub const NO_PARENT = std.math.maxInt(PartIndex);

pub const AnatomyTag = enum {
    // Human exterior bits
    Head,
    Eye,
    Nose,
    Ear,
    Neck,
    Torso,
    Abdomen,
    Shoulder,
    Groin,
    Arm,
    Elbow,
    Forearm,
    Wrist,
    Hand,
    Finger,
    Thumb,
    Thigh,
    Knee,
    Shin,
    Ankle,
    Foot,
    Toe,
    // Human organs
    Brain,
    Heart,
    Lung,
    Stomach,
    Liver,
    Intestine,
    Tongue,
    Trachea,
    Spleen,
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

pub const Side = enum(u8) { Left, Right, Center, None };

pub const TissueLayer = enum { Bone, Artery, Muscle, Fat, Nerve, Skin };

pub const BodyPart = struct {
    name_hash: u32, // e.g. hash("left_index_finger") for lookups
    def_id: u16,
    tag: AnatomyTag,
    parent: ?PartIndex, // Index of the body part this is attached to

    integrity: f32, // destroyed at 0.0
    wounds: std.ArrayList(Wound),
    is_severed: bool, // If true, all children are implicitly disconnected

    // FIXME: performantly look up PartDef flags before checking condition
    // must we also check parent isn't severed?
    fn can_grasp(self: *BodyPart) bool {
        self.integrity > 0.6;
    }

    fn can_support_weight(self: *BodyPart) bool {
        self.integrity > 0.3;
    }

    fn can_walk(self: *BodyPart) bool {
        self.integrity > 0.4;
    }

    fn can_run(self: *BodyPart) bool {
        self.integrity > 0.8;
    }

    fn can_write(self: *BodyPart) bool {
        self.integrity > 0.8;
    }

    // durability: f32, // an abstraction of density, circumference & hardness. Influenced by species + individual traits.
    // armour: precompute protective layers
};

pub const PartDef = struct {
    // 1. TOPOLOGY
    // Index in the blueprint array. 'null' means this is the Root (Torso).
    // We use ?u16 because u16 allows 65,535 parts (plenty).
    parent_id: ?u16,

    // 2. SEMANTICS
    tag: AnatomyTag, // The generic type (.Finger, .Arm, .Eye)
    side: Side, // .Left, .Right, .Center, .None
    name: []const u8, // "Left Index Finger" (Useful for combat logs)

    base_hit_chance: f32,
    base_durability: f32, // universal for all creatures with this topology
    trauma_mult: f32, // eyes, testicles ..

    // 4. FLAGS (Bitfield)
    flags: packed struct {
        is_vital: bool = false, // Brain/Heart: Destroy = Instant Death
        is_internal: bool = false, // Must penetrate parent layer to hit
        can_grasp: bool = false, // Hand/Tentacle
        can_stand: bool = false, // Leg/Foot: Break = Fall over
        can_see: bool = false, // no eye, no see
        can_hear: bool = false,
    } = .{},
};

pub const Body = struct {
    parts: std.ArrayList(BodyPart),

    // Helper to find things
    pub fn get_children(self: Body, parent: PartIndex) std.Iterator {
        _ = .{ self, parent };
        // TODO: implement
    }
};

pub const Wound = struct {
    tissue: TissueLayer,
    severity: f32, // 0.0 to 1.0 (Severed / Crushed)
    type: enum { Blunt, Cut, Pierce, Burn, Acid },
    // dressing
    // infection
};

// An array of nodes defining the topology
pub const HumanoidPlan = [_]PartDef{
    .{ .tag = .Torso, .parent = null },
    .{ .tag = .Head, .parent_id = 0 },
    .{ .tag = .Neck, .parent_id = 1 },
    // ...
};
