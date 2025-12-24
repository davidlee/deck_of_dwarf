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
    thickness: f32, // cm - affects penetration cost
    hardness: f32, // deflection chance for glancing blows
    flexibility: f32, // affects mobility penalty, gap size
};

// coverage of a particular part by a particular material - or,
// how hard is it to get around the tough stuff with a lucky stab or a shiv in the kidneys?
const Totality = enum {
    // full-fit simple construction (gambeson, etc) with no secondary materials
    total,
    // as good as it gets. More fully articulated plates than a pixar film about anthropomorphic
    // kitchen utensils - only visor slits, armpits, etc admit any entry.
    intimidating,
    // a practical compromise, but with attention paid to the back and kidneys, calves, etc.
    comprehensive,
    // most of the bits that might get hit - as long as you're facing the right way.
    frontal,
    // concerningly optimistic, e.g. a miserly panel over the vitals
    minimal,

    /// Chance (0-1) that an attack finds a gap in this coverage
    pub fn gapChance(self: Totality) f32 {
        return switch (self) {
            .total => 0.0,
            .intimidating => 0.05,
            .comprehensive => 0.15,
            .frontal => 0.30,
            .minimal => 0.50,
        };
    }
};

/// Runtime coverage for a specific piece of armor on a specific part
const InstanceCoverage = struct {
    part_tag: body.PartTag,
    side: body.Side, // resolved at instantiation
    layer: inventory.Layer,
    totality: Totality,
    material: *const Material,
    integrity: f32, // current durability (0 = destroyed)
    // tags: ?[]const Tag, // TODO: enchantments, conditions (dented, rusted, etc)
};

/// Design-time coverage pattern - reusable across bodies
const PatternCoverage = struct {
    part_tags: []const body.PartTag,
    side: ?body.Side, // null = assigned on instantiation (e.g., "left pauldron")
    layer: inventory.Layer,
    totality: Totality,
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

/// A specific piece of armor with runtime state
const Instance = struct {
    name: []const u8,
    template_id: u64,
    id: entity.ID,
    coverage: []InstanceCoverage, // unpacked from template, tracks integrity per-part
    // tags: ?[]const Tag, // TODO: enchantments, conditions

    pub fn init(alloc: std.mem.Allocator, template: *const Template, side_assignment: ?body.Side) !Instance {
        _ = .{ template, alloc, side_assignment };
        // Unpack template.pattern into []InstanceCoverage:
        // - Expand part_tags into individual entries
        // - Resolve side: use pattern.side if set, else side_assignment
        // - Set integrity = material.durability * quality_modifier
        @panic("TODO: implement Instance.init");
    }

    pub fn deinit(self: *Instance, alloc: std.mem.Allocator) void {
        alloc.free(self.coverage);
    }
};

/// Runtime armor state for a specific body, optimized for combat lookups
pub const Stack = struct {
    alloc: std.mem.Allocator,
    // PartIndex → layers covering that part (indexed by inventory.Layer)
    coverage: std.AutoHashMap(body.PartIndex, [9]?LayerProtection),

    pub const LayerProtection = struct {
        material: *const Material,
        totality: Totality,
        integrity: *f32, // pointer back to Instance.coverage[].integrity for mutation
    };

    pub fn init(alloc: std.mem.Allocator) Stack {
        return .{
            .alloc = alloc,
            .coverage = std.AutoHashMap(body.PartIndex, [9]?LayerProtection).init(alloc),
        };
    }

    pub fn deinit(self: *Stack) void {
        self.coverage.deinit();
    }

    /// Rebuild stack from equipped armor instances for a specific body
    pub fn buildFromEquipped(self: *Stack, bod: *const body.Body, equipped: []const *Instance) !void {
        self.coverage.clearRetainingCapacity();

        for (equipped) |instance| {
            for (instance.coverage) |*cov| {
                // Resolve PartTag + Side → PartIndex using body's lookup
                const part_idx = resolvePartIndex(bod, cov.part_tag, cov.side) orelse continue;

                const entry = try self.coverage.getOrPut(part_idx);
                if (!entry.found_existing) {
                    entry.value_ptr.* = [_]?LayerProtection{null} ** 9;
                }

                const layer_idx = @intFromEnum(cov.layer);
                entry.value_ptr[layer_idx] = .{
                    .material = cov.material,
                    .totality = cov.totality,
                    .integrity = &cov.integrity,
                };
            }
        }
    }

    /// Get protection layers for a part, outer to inner (Cloak → Skin)
    pub fn getProtection(self: *const Stack, part_idx: body.PartIndex) [9]?LayerProtection {
        return self.coverage.get(part_idx) orelse [_]?LayerProtection{null} ** 9;
    }
};

/// Resolve PartTag + Side to PartIndex for a specific body
fn resolvePartIndex(bod: *const body.Body, tag: body.PartTag, side: body.Side) ?body.PartIndex {
    // Search for matching part - TODO: could precompute (tag,side) → index map
    for (bod.parts.items, 0..) |part, i| {
        if (part.tag == tag and part.side == side) {
            return @intCast(i);
        }
    }
    return null;
}

/// Result of armor absorbing damage
pub const AbsorptionResult = struct {
    remaining: damage.Packet, // damage that reached the body
    gap_found: bool, // attack bypassed armor entirely
    layers_hit: u8, // number of armor layers damaged
};

/// Process a damage packet through armor layers, returning what reaches the body.
/// Mutates layer integrity as armor is damaged.
pub fn resolveThroughArmor(
    stack: *const Stack,
    part_idx: body.PartIndex,
    packet: damage.Packet,
    rng: *std.Random,
) AbsorptionResult {
    var remaining = packet;
    var layers_hit: u8 = 0;
    const protection = stack.getProtection(part_idx);

    // Process layers outer to inner (Cloak=8 down to Skin=0)
    var layer_idx: usize = 9;
    while (layer_idx > 0) {
        layer_idx -= 1;
        const layer = protection[layer_idx] orelse continue;

        // Skip destroyed armor
        if (layer.integrity.* <= 0) continue;

        // Gap check - attack might find a hole
        if (rng.float(f32) < layer.totality.gapChance()) {
            continue; // slipped through
        }

        layers_hit += 1;

        // Hardness check - glancing blow deflection
        if (rng.float(f32) < layer.material.hardness) {
            // Deflected - minimal damage to armor, attack stopped
            layer.integrity.* -= remaining.amount * 0.1;
            remaining.amount = 0;
            break;
        }

        // Material resistance reduces damage
        const resistance = getMaterialResistance(layer.material, remaining.kind);
        if (remaining.amount < resistance.threshold) {
            // Below threshold - no penetration, minor armor wear
            layer.integrity.* -= remaining.amount * 0.05;
            remaining.amount = 0;
            break;
        }

        // Damage that gets through
        const effective_damage = (remaining.amount - resistance.threshold) * resistance.ratio;
        const absorbed = remaining.amount - effective_damage;

        // Armor takes damage
        layer.integrity.* -= absorbed * 0.5;

        // Penetration reduced by thickness
        remaining.penetration -= layer.material.thickness;
        remaining.amount = effective_damage;

        // If penetration exhausted, stop (for piercing/slashing)
        if (remaining.penetration <= 0 and
            (remaining.kind == .pierce or remaining.kind == .slash))
        {
            remaining.amount = 0;
            break;
        }
    }

    return .{
        .remaining = remaining,
        .gap_found = layers_hit == 0 and remaining.amount > 0,
        .layers_hit = layers_hit,
    };
}

fn getMaterialResistance(material: *const Material, kind: damage.Kind) Resistance {
    for (material.self_resistances) |res| {
        if (res.damage == kind) return res;
    }
    // No specific resistance - use defaults
    return .{ .damage = kind, .threshold = 0, .ratio = 1.0 };
}
