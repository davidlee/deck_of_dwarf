const std = @import("std");
const combat = @import("combat.zig");
const cards = @import("cards.zig");
const weapon = @import("weapon.zig");
const damage = @import("damage.zig");
const armour = @import("armour.zig");
const body = @import("body.zig");
const entity = @import("entity.zig");
const events = @import("events.zig");
const world = @import("world.zig");
const stats = @import("stats.zig");

const Agent = combat.Agent;
const Engagement = combat.Engagement;
const Technique = cards.Technique;
const TechniqueID = cards.TechniqueID;
const Stakes = cards.Stakes;
const World = world.World;
const Event = events.Event;

// ============================================================================
// Outcome Determination
// ============================================================================

pub const Outcome = enum {
    hit,
    miss,
    blocked,
    parried,
    deflected,
    dodged,
    countered,
};

pub const AttackContext = struct {
    attacker: *Agent,
    defender: *Agent,
    technique: *const Technique,
    weapon_template: *const weapon.Template,
    stakes: Stakes,
    engagement: *Engagement,
};

pub const DefenseContext = struct {
    defender: *Agent,
    technique: ?*const Technique, // null = passive defense
    weapon_template: *const weapon.Template,
};

/// Calculate hit probability for an attack
pub fn calculateHitChance(attack: AttackContext, defense: DefenseContext) f32 {
    var chance: f32 = 0.5; // Base 50%

    // Technique difficulty (higher = harder to land)
    chance -= attack.technique.difficulty * 0.1;

    // Weapon accuracy modifier
    if (getWeaponOffensive(attack.weapon_template, attack.technique.id)) |weapon_off| {
        chance += weapon_off.accuracy * 0.1;
    }

    // Stakes modifier
    chance += switch (attack.stakes) {
        .probing => -0.1,
        .guarded => 0.0,
        .committed => 0.1,
        .reckless => 0.2,
    };

    // Engagement advantage (pressure, control, position)
    const engagement_bonus = (attack.engagement.playerAdvantage() - 0.5) * 0.3;
    chance += if (attack.attacker.director == .player) engagement_bonus else -engagement_bonus;

    // Attacker balance
    chance += (attack.attacker.balance - 0.5) * 0.2;

    // Defense modifiers
    if (defense.technique) |def_tech| {
        // Active defense technique modifies attacker's chance
        const def_mult = switch (def_tech.id) {
            .parry => attack.technique.parry_mult,
            .block => attack.technique.deflect_mult, // using deflect as proxy for now
            .deflect => attack.technique.deflect_mult,
            else => 1.0,
        };
        chance *= def_mult;

        // Defender weapon defensive modifiers
        chance -= defense.weapon_template.defence.parry * 0.1;
    }

    // Defender balance (low balance = easier to hit)
    chance += (1.0 - defense.defender.balance) * 0.15;

    return std.math.clamp(chance, 0.05, 0.95);
}

/// Determine outcome of attack vs defense
pub fn resolveOutcome(
    w: *World,
    attack: AttackContext,
    defense: DefenseContext,
) !Outcome {
    const hit_chance = calculateHitChance(attack, defense);
    const roll = try w.drawRandom(.combat);

    if (roll > hit_chance) {
        // Attack failed - determine how based on defense
        if (defense.technique) |def_tech| {
            return switch (def_tech.id) {
                .parry => .parried,
                .block => .blocked,
                .deflect => .deflected,
                else => .miss,
            };
        }
        return .miss;
    }

    return .hit;
}

// ============================================================================
// Advantage Effects
// ============================================================================

pub const AdvantageEffect = struct {
    pressure: f32 = 0,
    control: f32 = 0,
    position: f32 = 0,
    self_balance: f32 = 0,
    target_balance: f32 = 0,

    pub fn apply(
        self: AdvantageEffect,
        engagement: *Engagement,
        attacker: *Agent,
        defender: *Agent,
    ) void {
        engagement.pressure = std.math.clamp(engagement.pressure + self.pressure, 0, 1);
        engagement.control = std.math.clamp(engagement.control + self.control, 0, 1);
        engagement.position = std.math.clamp(engagement.position + self.position, 0, 1);
        attacker.balance = std.math.clamp(attacker.balance + self.self_balance, 0, 1);
        defender.balance = std.math.clamp(defender.balance + self.target_balance, 0, 1);
    }

    pub fn scale(self: AdvantageEffect, mult: f32) AdvantageEffect {
        return .{
            .pressure = self.pressure * mult,
            .control = self.control * mult,
            .position = self.position * mult,
            .self_balance = self.self_balance * mult,
            .target_balance = self.target_balance * mult,
        };
    }

    /// Apply advantage effects and emit events for any changes
    pub fn applyWithEvents(
        self: AdvantageEffect,
        w: *World,
        engagement: *Engagement,
        attacker: *Agent,
        defender: *Agent,
    ) !void {
        // Capture old values
        const old_pressure = engagement.pressure;
        const old_control = engagement.control;
        const old_position = engagement.position;
        const old_attacker_balance = attacker.balance;
        const old_defender_balance = defender.balance;

        // Apply changes
        self.apply(engagement, attacker, defender);

        // Emit events for changed values
        // Engagement changes are relative to defender (engagement stored on mob)
        if (self.pressure != 0) {
            try w.events.push(.{ .advantage_changed = .{
                .agent_id = defender.id,
                .engagement_with = attacker.id,
                .axis = .pressure,
                .old_value = old_pressure,
                .new_value = engagement.pressure,
            } });
        }
        if (self.control != 0) {
            try w.events.push(.{ .advantage_changed = .{
                .agent_id = defender.id,
                .engagement_with = attacker.id,
                .axis = .control,
                .old_value = old_control,
                .new_value = engagement.control,
            } });
        }
        if (self.position != 0) {
            try w.events.push(.{ .advantage_changed = .{
                .agent_id = defender.id,
                .engagement_with = attacker.id,
                .axis = .position,
                .old_value = old_position,
                .new_value = engagement.position,
            } });
        }
        // Balance is intrinsic (engagement_with = null)
        if (self.self_balance != 0) {
            try w.events.push(.{ .advantage_changed = .{
                .agent_id = attacker.id,
                .engagement_with = null,
                .axis = .balance,
                .old_value = old_attacker_balance,
                .new_value = attacker.balance,
            } });
        }
        if (self.target_balance != 0) {
            try w.events.push(.{ .advantage_changed = .{
                .agent_id = defender.id,
                .engagement_with = null,
                .axis = .balance,
                .old_value = old_defender_balance,
                .new_value = defender.balance,
            } });
        }
    }
};

/// Get advantage effect for a technique outcome
pub fn getAdvantageEffect(outcome: Outcome, stakes: Stakes) AdvantageEffect {
    const base: AdvantageEffect = switch (outcome) {
        .hit => .{
            .pressure = 0.15,
            .control = 0.10,
            .target_balance = -0.15,
        },
        .miss => .{
            .control = -0.15,
            .self_balance = -0.10,
        },
        .blocked => .{
            .pressure = 0.05,
            .control = -0.05,
        },
        .parried => .{
            .control = -0.20,
            .self_balance = -0.05,
        },
        .deflected => .{
            .pressure = 0.05,
            .control = -0.10,
        },
        .dodged => .{
            .control = -0.10,
            .self_balance = -0.05,
        },
        .countered => .{
            .control = -0.25,
            .self_balance = -0.15,
        },
    };

    // Scale by stakes - higher stakes = bigger swings
    const is_success = (outcome == .hit);
    const mult: f32 = switch (stakes) {
        .probing => 0.5,
        .guarded => 1.0,
        .committed => if (is_success) 1.25 else 1.5,
        .reckless => if (is_success) 1.5 else 2.0,
    };

    return base.scale(mult);
}

// ============================================================================
// Damage Packet Creation
// ============================================================================

fn getWeaponOffensive(
    weapon_template: *const weapon.Template,
    technique_id: TechniqueID,
) ?*const weapon.Offensive {
    return switch (technique_id) {
        .thrust => if (weapon_template.thrust) |*t| t else null,
        .swing => if (weapon_template.swing) |*s| s else null,
        else => if (weapon_template.swing) |*s| s else null,
    };
}

pub fn createDamagePacket(
    technique: *const Technique,
    weapon_template: *const weapon.Template,
    attacker: *Agent,
    stakes: Stakes,
) damage.Packet {
    // Get weapon offensive profile for this technique type
    const weapon_off = getWeaponOffensive(weapon_template, technique.id);

    // Base damage from technique instances
    var amount: f32 = 0;
    for (technique.damage.instances) |inst| {
        amount += inst.amount;
    }

    // Scale by attacker stats
    const stat_mult: f32 = switch (technique.damage.scaling.stats) {
        .stat => |accessor| attacker.stats.get(accessor),
        .average => |arr| blk: {
            const a = attacker.stats.get(arr[0]);
            const b = attacker.stats.get(arr[1]);
            break :blk (a + b) / 2.0;
        },
    };
    amount *= stat_mult * technique.damage.scaling.ratio;

    // Weapon damage modifier
    if (weapon_off) |off| {
        amount *= off.damage;
    }

    // Stakes modifier
    amount *= switch (stakes) {
        .probing => 0.4,
        .guarded => 1.0,
        .committed => 1.4,
        .reckless => 2.0,
    };

    // Primary damage type from technique
    const kind: damage.Kind = if (technique.damage.instances.len > 0 and
        technique.damage.instances[0].types.len > 0)
        technique.damage.instances[0].types[0]
    else
        .bludgeon;

    // Penetration from weapon
    const penetration: f32 = if (weapon_off) |off|
        off.penetration + off.penetration_max * 0.5
    else
        1.0;

    return damage.Packet{
        .amount = amount,
        .kind = kind,
        .penetration = penetration,
    };
}

// ============================================================================
// Full Resolution
// ============================================================================

pub const ResolutionResult = struct {
    outcome: Outcome,
    advantage_applied: AdvantageEffect,
    damage_packet: ?damage.Packet,
    armour_result: ?armour.AbsorptionResult,
    body_result: ?body.DamageResult,
};

/// Resolve a single technique against a defense, applying all effects
pub fn resolveTechniqueVsDefense(
    w: *World,
    attack: AttackContext,
    defense: DefenseContext,
    target_part: body.PartIndex,
) !ResolutionResult {
    // 1. Determine outcome (hit/miss/blocked/etc)
    const outcome = try resolveOutcome(w, attack, defense);

    // 2. Calculate and apply advantage effects (with events)
    const adv_effect = getAdvantageEffect(outcome, attack.stakes);
    try adv_effect.applyWithEvents(w, attack.engagement, attack.attacker, attack.defender);

    // 3. If hit, create damage packet and resolve through armor/body
    var dmg_packet: ?damage.Packet = null;
    var armour_result: ?armour.AbsorptionResult = null;
    var body_result: ?body.DamageResult = null;

    if (outcome == .hit) {
        dmg_packet = createDamagePacket(
            attack.technique,
            attack.weapon_template,
            attack.attacker,
            attack.stakes,
        );

        // Resolve through armor
        armour_result = try armour.resolveThroughArmourWithEvents(
            w,
            attack.defender.id,
            &attack.defender.armour,
            target_part,
            dmg_packet.?,
        );

        // Apply remaining damage to body (body emits its own events for wounds/severing)
        if (armour_result.?.remaining.amount > 0) {
            body_result = try attack.defender.body.applyDamageToPart(
                target_part,
                armour_result.?.remaining,
            );
        }
    }

    // Emit technique_resolved event
    try w.events.push(.{ .technique_resolved = .{
        .attacker_id = attack.attacker.id,
        .defender_id = attack.defender.id,
        .technique_id = attack.technique.id,
        .outcome = outcome,
    } });

    return ResolutionResult{
        .outcome = outcome,
        .advantage_applied = adv_effect,
        .damage_packet = dmg_packet,
        .armour_result = armour_result,
        .body_result = body_result,
    };
}

// ============================================================================
// Hit Location Selection
// ============================================================================

/// Select a target body part based on technique and engagement state
pub fn selectHitLocation(
    w: *World,
    defender: *Agent,
    technique: *const Technique,
    engagement: *const Engagement,
) !body.PartIndex {
    _ = technique; // TODO: weight by technique (thrust -> torso/head)
    _ = engagement; // TODO: weight by position (flanking -> back)

    // For now, simple random selection weighted by base_hit_chance
    const parts = defender.body.parts.items;
    var total_weight: f32 = 0;
    for (parts) |part| {
        total_weight += part.base_hit_chance;
    }

    const roll = try w.drawRandom(.combat) * total_weight;
    var cumulative: f32 = 0;
    for (parts, 0..) |part, i| {
        cumulative += part.base_hit_chance;
        if (roll <= cumulative) {
            return @intCast(i);
        }
    }

    // Fallback to first part (torso typically)
    return 0;
}

// ============================================================================
// Tests
// ============================================================================

test "calculateHitChance base case" {
    // Would need mock agents/engagement - placeholder for now
}

test "getAdvantageEffect scales by stakes" {
    const base_hit = getAdvantageEffect(.hit, .guarded);
    const reckless_hit = getAdvantageEffect(.hit, .reckless);

    // Reckless should have higher pressure gain
    try std.testing.expect(reckless_hit.pressure > base_hit.pressure);
}

test "getAdvantageEffect miss penalty scales with stakes" {
    const guarded_miss = getAdvantageEffect(.miss, .guarded);
    const reckless_miss = getAdvantageEffect(.miss, .reckless);

    // Reckless miss should have bigger balance penalty
    try std.testing.expect(reckless_miss.self_balance < guarded_miss.self_balance);
}
