# Stance System Design

## Problem

Hit location weighting needs to work across body types (humanoids, oozes, centaurs). The current `base_hit_chance` on body parts doesn't capture:

1. **Positional context** - a prone body is "all low" but anatomy hasn't changed
2. **Dynamic positioning** - arms can be high/mid/low depending on guard
3. **Technique interaction** - a spear thrust exposes the hands

## Core Insight

**Stance is positional, not anatomical.**

- Body = pure anatomy (what parts exist, connections, wound capacity)
- Stance = how those parts are arranged in space right now
- Techniques can force stance changes, creating tactical consequences

## Data Model

### Height Representation

**Open question: enum vs f32**

Enum `{ low, mid, high }`:
- Simple for defense matching ("high guard covers high")
- Clean technique targeting ("targets mid")
- Loses gradients (slash centered high but tails into mid)

Continuous `f32` (0.0 = ground, 1.0 = max):
- Attack has `target_height` + `spread` for distribution
- Defense covers a range (high guard: 0.6-1.0)
- More expressive but more complex
- Enables reaction cost = distance to adjust

**Hybrid possibility**: f32 for targeting math, but define named zones for defense/UI.

### Flexible Parts

Some parts (hands, arms) can move within a stance without changing the whole stance.

Options:
- `height_range: struct { min: f32, max: f32 }` - part can be anywhere in range
- `flexible: bool` - matches adjacent heights
- Per-part height override when technique implies stance

### Proposed Structures

```zig
// body.zig
pub const Height = enum { low, mid, high };
// Or: pub const Height = f32; // 0.0-1.0

pub const PartExposure = struct {
    tag: PartTag,
    side: Side,           // for L|R matching
    hit_chance: f32,      // base probability in this stance
    height: Height,       // or f32
    // height_range: ?struct { min: f32, max: f32 }, // for flexible parts
};

pub const StanceDefinition = struct {
    name: []const u8,
    exposures: []const PartExposure,
    // mirror: bool, // if true, L|R can be flipped based on dominant hand
};

// Blueprint/Plan gains:
stances: []const StanceDefinition,
default_stance: []const u8,

// Part loses:
// base_hit_chance: f32,  // REMOVED - now lives in stance
```

```zig
// combat.zig Agent
stance: *const StanceDefinition,
prior_stance: ?*const StanceDefinition,  // for revert after technique
```

```zig
// cards.zig Technique
implied_stance: ?[]const u8 = null,   // stance during execution
exit_stance: ?[]const u8 = null,      // null = revert to prior_stance

// Targeting (details TBD based on height model)
target_height: ?Height = null,        // enum version
// Or: target_height: f32, height_spread: f32,  // continuous version
```

## L|R Mirroring

Many stances are symmetric but favoring one side (lead with left vs right).

- Define stance once with canonical side assignment
- Mirror flag or separate mirroring logic flips L↔R based on dominant hand
- Technique's `implied_stance` resolves using agent's `dominant_side`

Example: "right lead" stance has right hand forward (high), left hand back (mid).
For a left-handed fighter, this becomes "left lead" with parts swapped.

## Attack Height Mechanics

### Enum Approach
```zig
target_height: ?Height = null,  // null = no preference

// Resolution: parts matching target_height get bonus multiplier
// Parts at adjacent heights get smaller bonus
// Parts at opposite height get penalty
```

### Continuous Approach
```zig
target_height: f32 = 0.5,   // center of attack (0.0-1.0)
height_spread: f32 = 0.3,   // width of distribution

// Resolution: for each part, calculate overlap between
// attack range and part's height (or height_range)
// Weight hit_chance by overlap amount
```

**Example attacks (continuous):**
- Downward slash: `target: 0.75, spread: 0.35` - centered high, spreads to mid
- Thrust: `target: 0.5, spread: 0.15` - tight cluster at mid
- Leg sweep: `target: 0.15, spread: 0.2` - low only

## Defense Height Mechanics

Defensive techniques cover height zones:

```zig
// Enum: covers one primary height, maybe adjacent
guard_height: Height,
covers_adjacent: bool,

// Continuous: covers a range
guard_min: f32,
guard_max: f32,
```

**Reaction cost**: adjusting defense one "step" (low→mid, mid→high) costs stamina. This creates tactical depth - feint high, strike low.

## Resolution Algorithm

```
1. Attacker commits technique
   - If implied_stance, save prior_stance, switch to implied

2. Defender's active defense (if any) establishes coverage

3. selectHitLocation():
   a. Get defender's current stance exposures
   b. Filter/weight by technique's target_height preference
   c. Apply defense coverage (reduce hit_chance for covered heights)
   d. Random selection from weighted distribution

4. Resolve hit/miss, damage, etc.

5. Technique ends
   - If exit_stance set, switch to it
   - Else revert to prior_stance
```

## Starting Point: "Standing Frontwise"

Migrate current humanoid hit chances to a default stance:

```zig
const standing_frontwise = StanceDefinition{
    .name = "standing_frontwise",
    .exposures = &.{
        // High
        .{ .tag = .head,     .side = .center, .hit_chance = 0.10, .height = .high },
        .{ .tag = .neck,     .side = .center, .hit_chance = 0.04, .height = .high },
        .{ .tag = .eye,      .side = .left,   .hit_chance = 0.01, .height = .high },
        .{ .tag = .eye,      .side = .right,  .hit_chance = 0.01, .height = .high },
        .{ .tag = .ear,      .side = .left,   .hit_chance = 0.01, .height = .high },
        .{ .tag = .ear,      .side = .right,  .hit_chance = 0.01, .height = .high },
        .{ .tag = .nose,     .side = .center, .hit_chance = 0.02, .height = .high },

        // Mid
        .{ .tag = .torso,    .side = .center, .hit_chance = 0.30, .height = .mid },
        .{ .tag = .abdomen,  .side = .center, .hit_chance = 0.15, .height = .mid },
        .{ .tag = .shoulder, .side = .left,   .hit_chance = 0.02, .height = .mid },
        .{ .tag = .shoulder, .side = .right,  .hit_chance = 0.02, .height = .mid },
        .{ .tag = .arm,      .side = .left,   .hit_chance = 0.025, .height = .mid },
        .{ .tag = .arm,      .side = .right,  .hit_chance = 0.025, .height = .mid },
        .{ .tag = .forearm,  .side = .left,   .hit_chance = 0.025, .height = .mid },
        .{ .tag = .forearm,  .side = .right,  .hit_chance = 0.025, .height = .mid },
        .{ .tag = .elbow,    .side = .left,   .hit_chance = 0.01, .height = .mid },
        .{ .tag = .elbow,    .side = .right,  .hit_chance = 0.01, .height = .mid },
        .{ .tag = .wrist,    .side = .left,   .hit_chance = 0.01, .height = .mid },
        .{ .tag = .wrist,    .side = .right,  .hit_chance = 0.01, .height = .mid },
        .{ .tag = .hand,     .side = .left,   .hit_chance = 0.015, .height = .mid },
        .{ .tag = .hand,     .side = .right,  .hit_chance = 0.015, .height = .mid },

        // Low
        .{ .tag = .groin,    .side = .center, .hit_chance = 0.03, .height = .low },
        .{ .tag = .thigh,    .side = .left,   .hit_chance = 0.04, .height = .low },
        .{ .tag = .thigh,    .side = .right,  .hit_chance = 0.04, .height = .low },
        .{ .tag = .knee,     .side = .left,   .hit_chance = 0.01, .height = .low },
        .{ .tag = .knee,     .side = .right,  .hit_chance = 0.01, .height = .low },
        .{ .tag = .shin,     .side = .left,   .hit_chance = 0.025, .height = .low },
        .{ .tag = .shin,     .side = .right,  .hit_chance = 0.025, .height = .low },
        .{ .tag = .ankle,    .side = .left,   .hit_chance = 0.01, .height = .low },
        .{ .tag = .ankle,    .side = .right,  .hit_chance = 0.01, .height = .low },
        .{ .tag = .foot,     .side = .left,   .hit_chance = 0.015, .height = .low },
        .{ .tag = .foot,     .side = .right,  .hit_chance = 0.015, .height = .low },
    },
};
```

Note: fingers, toes, internal organs omitted (hit_chance = 0 or covered by parent).

## Compositional Stance Model

Rather than named stances with combinatorial explosion, stance **emerges** from composing two independent axes:

### Contribution Axes

```
Arms/Grip (from weapon + technique)     Legs/Body (from footwork/maneuver)
───────────────────────────────────     ──────────────────────────────────
Grip category (weapon property):        Facing:
  - single_hand                           - squared (direct)
  - two_hand_long                         - bladed (lead side forward)
  - two_hand_polearm / half_grip
  - polearm_extended                    Weight distribution:
  - main_and_off                          - back-weighted (-1)
                                          - neutral (0)
Arm position (technique modifier):        - forward-leaning (+1)
  - height: high / mid / low
  - extension: retracted ↔ extended     Width:
                                          - narrow / normal / wide
```

### Composition Flow

```
1. Weapon grip category → base arm exposure pattern
2. Attack/defense technique → modifies arm height + extension
3. Footwork/maneuver card → body stance (facing, weight, width)
4. Body facing → applies lead/rear modifier to arm exposures
5. Synthesize → effective exposure map for resolution
```

### Facing as Modifier

Bladed stance exposes the lead side more, protects the rear. This is a **modifier** applied to arm exposures after grip/technique resolve:

```zig
pub const BodyContribution = struct {
    facing: Facing,
    weight: f32,              // -1 back, +1 forward
    width: Width,

    // Modifiers applied to arm-side exposures
    lead_exposure_mod: f32,   // e.g., +0.15 for bladed
    rear_exposure_mod: f32,   // e.g., -0.10 for bladed
};

pub const Facing = enum {
    squared,       // 0 modifier both sides
    bladed_left,   // left side leads
    bladed_right,  // right side leads
};
```

Resolution uses `agent.dominant_side` to determine which arm is "lead" vs "rear".

### Grip Categories

Fold similar weapon grips to reduce combinatorics:

| Category | Weapons | Characteristics |
|----------|---------|-----------------|
| `single_hand` | rapier, arming sword, messer, saber | One arm active, off-hand free or incidental |
| `two_hand_long` | longsword, greatsword, katana | Both hands on hilt, full extension |
| `two_hand_short` | half-sword, halberd at guard, shortened spear | Both hands, choked up, more control |
| `polearm_extended` | spear at reach, pike, halberd extended | Maximum reach, hands spread on shaft |
| `main_and_off` | sword+buckler, sword+dagger, rapier+cloak | Primary weapon + active off-hand defense/offense |

Each category defines a base exposure pattern for the arms/hands.

### Technique Contributions

Attack and defense techniques modify the arm configuration:

```zig
// cards.zig Technique
pub const ArmContribution = struct {
    height: ?Height = null,       // high/mid/low override
    extension: ?f32 = null,       // 0.0 retracted ↔ 1.0 full extension
    hand_exposure: ?f32 = null,   // extra exposure for hands (thrust = high)
};

// On Technique:
arm_contribution: ArmContribution = .{},
```

**Examples:**
- Thrust: `{ .height = .mid, .extension = 0.9, .hand_exposure = 0.15 }`
- High guard: `{ .height = .high, .extension = 0.3 }`
- Half-sword thrust: `{ .height = .mid, .extension = 0.6 }` (shorter reach)

### Footwork Contributions

Maneuver cards contribute body stance:

```zig
pub const BodyContribution = struct {
    facing: ?Facing = null,
    weight: ?f32 = null,
    width: ?Width = null,
    crouch: ?f32 = null,          // 0 standing ↔ 1 full crouch
};

// On maneuver card:
body_contribution: BodyContribution = .{},
```

**Examples:**
- Advance: `{ .weight = 0.4, .facing = .bladed_dominant }`
- Retreat: `{ .weight = -0.5 }`
- Sidestep: `{ .facing = .bladed_off }` (switch lead)
- Crouch: `{ .crouch = 0.6, .width = .wide }`

### Synthesis Algorithm

```zig
pub fn synthesizeExposures(
    grip: GripCategory,
    arm_mods: ArmContribution,
    body_mods: BodyContribution,
    dominant_side: Side,
) ExposureMap {
    // 1. Start with grip's base arm exposure pattern
    var exposures = grip.baseExposures();

    // 2. Apply arm height/extension from technique
    if (arm_mods.height) |h| {
        exposures.setArmHeight(h);
    }
    if (arm_mods.extension) |ext| {
        exposures.scaleArmExposure(ext);  // more extension = more exposed
    }
    if (arm_mods.hand_exposure) |he| {
        exposures.addHandExposure(he);
    }

    // 3. Apply body facing modifiers
    const lead_side = body_mods.facing.leadSide(dominant_side);
    exposures.applyFacingMods(lead_side, body_mods.lead_exposure_mod, body_mods.rear_exposure_mod);

    // 4. Apply crouch (shifts everything toward low)
    if (body_mods.crouch) |c| {
        exposures.applyCrouch(c);
    }

    // 5. Apply weight distribution (affects leg exposure, recovery options)
    if (body_mods.weight) |w| {
        exposures.applyWeight(w);
    }

    return exposures;
}
```

### Conflict Handling

When arm and body contributions conflict:

1. **Impossible pairings**: Some combinations are mechanically invalid
   - Can't do polearm_extended from full crouch
   - System rejects pairing at card-play validation

2. **Disadvantaged pairings**: Some combinations work but poorly
   - High guard + forward lunge = overextended, penalty to recovery
   - Represented as worse exposure or stamina cost

3. **Synergistic pairings**: Some combinations are better than parts
   - Thrust + advance = momentum bonus
   - Could grant damage/accuracy bonus beyond just exposure math

### Data Footprint Comparison

**Named stances approach:**
- N grip types × M body stances × P technique variants = explosion
- 5 grips × 4 facings × 3 heights × 2 extensions = 120 named stances

**Compositional approach:**
- 5 grip base patterns
- ~6 body stance presets (or freeform contribution)
- Per-technique arm modifiers (3-4 floats)
- Synthesis algorithm

Much smaller data footprint, richer expression space.

## Relative Angle and Part Facing

Stance composition tells us how the *attacker* is positioned. We also need to model *relative angle* - whether the attacker has flanked or gotten behind the defender.

### Angle as Engagement Property

Angle is relational (between two combatants), so it lives on `Engagement`:

```zig
// combat.zig Engagement gains:
pub const RelativeAngle = enum {
    frontal,        // facing each other directly
    inside,         // attacker on defender's weapon side (~30-45°)
    outside,        // attacker on defender's off-hand side (~30-45°)
    flank,          // ~90° - full side
    rear,           // behind (~135-180°)
};

angle: RelativeAngle = .frontal,
```

### Part Facing (One Field, No Duplication)

Each body part has a primary facing - the direction it naturally presents from:

```zig
pub const PrimaryFacing = enum {
    front,   // torso, face, kneecap, front of thigh
    back,    // spine, back of head, back of knee
    outer,   // outer arm/leg surfaces (combines with side)
    inner,   // armpits, inner thighs
    any,     // top of head, groin - equally accessible
};

// On PartDef (one new field):
facing: PrimaryFacing = .front,
```

**No part duplication.** The knee is one part. Attack angle determines whether you're hitting the kneecap or the back of the knee - same part, different accessibility and armor coverage.

### Accessibility Derivation

```zig
pub const AccessLevel = enum {
    full,      // 1.0x hit chance
    partial,   // 0.5x hit chance
    grazing,   // 0.2x hit chance
    none,      // 0 (or tiny lucky-hit chance)
};

fn deriveAccess(
    part_facing: PrimaryFacing,
    part_side: Side,
    attack_angle: RelativeAngle,
    defender_dominant: Side,
) AccessLevel {
    return switch (part_facing) {
        .front => switch (attack_angle) {
            .frontal => .full,
            .inside, .outside => .partial,
            .flank => .grazing,
            .rear => .none,
        },
        .back => switch (attack_angle) {
            .rear => .full,
            .flank => .partial,
            .inside, .outside => .grazing,
            .frontal => .none,
        },
        .outer => blk: {
            // Accessible when angle matches part's side
            const part_is_lead = (part_side == defender_dominant);
            break :blk switch (attack_angle) {
                .inside => if (part_is_lead) .full else .grazing,
                .outside => if (!part_is_lead) .full else .grazing,
                .flank => .partial,
                .frontal, .rear => .grazing,
            };
        },
        .inner => // inverse of .outer logic
        .any => .full,
    };
}
```

### Armor Integration

Totality determines if armor covers this angle on this part:

```zig
// Armor layer specifies which facings it covers:
pub const ArmorCoverage = packed struct {
    front: bool = true,
    back: bool = false,
    sides: bool = false,
};

// On armor piece:
coverage: ArmorCoverage,
```

Resolution:
1. Attack angle + part facing → which "side" of the part is hit
2. Check if armor's coverage includes that side
3. If not covered → armor bypassed (gap hit, or just skin/padding)

**Examples:**
- Breastplate: `{ .front = true }` - protects front-facing parts from frontal attacks
- Full cuirass: `{ .front = true, .back = true }` - protects front and back
- Mail hauberk: `{ .front = true, .back = true, .sides = true }` - full Totality

### Hooked Weapons

Weapons already have `Features.hooked: bool`. When combined with appropriate technique, grants a chance to hit from a non-facing angle.

```zig
// Resolution: if hooked weapon + hooking technique, roll for angle bypass
fn resolveHitAngle(
    engagement_angle: RelativeAngle,
    weapon: *const Weapon,
    technique: *const Technique,
    rng: *Random,
) RelativeAngle {
    if (weapon.features.hooked and technique.can_hook) {
        // Chance to hit back-facing surface from front
        if (rng.float() < 0.3) {  // tunable
            return .rear;  // or opposite of current angle
        }
    }
    return engagement_angle;
}
```

**Examples:**
- Axe beard hooks behind knee → greaves only cover front, back of knee exposed
- Billhook pulls rider → bypasses frontal armor
- Bec de corbin spike reaches around shield

**On Technique:**
```zig
can_hook: bool = false,  // enables hook resolution when weapon.features.hooked
```

Simple boolean combo, no need to specify which angle - hooking hits the "back" of whatever part is selected.

### Techniques That Create Angle

Footwork/maneuver cards can shift the engagement angle:

```zig
// On maneuver technique:
angle_change: ?struct {
    direction: enum { inside, outside, either },
    magnitude: enum { step, full },  // step = one level, full = to flank
} = null,
```

**Examples:**
- Sidestep inside: `{ .direction = .inside, .magnitude = .step }`
- Circle to flank: `{ .direction = .either, .magnitude = .full }`

Gaining angle becomes a tactical objective alongside pressure/control. Angle converts advantage into exposed targets and armor gaps.

### Inside vs Outside Trade-offs

| Angle | Risk | Reward |
|-------|------|--------|
| Inside (weapon side) | Closer to defender's weapon, easier to counter | Shorter path to vitals, better control |
| Outside (off-hand side) | Off-hand may have shield/dagger | Safer from main weapon, back access easier |

This interacts with `main_and_off` grip - sword+buckler defender is harder to outside-angle than sword-alone.

## Comptime Stance Expansion

Stance definitions should stay compact - no need to author entries for every finger and toe. Child parts are expanded at comptime.

### Authored Format (Compact)

```zig
const standing_frontwise_src = [_]ExposureEntry{
    // Major parts only - children auto-expand
    .{ .tag = .head,  .side = .center, .hit_chance = 0.10, .height = .high },
    .{ .tag = .hand,  .side = .left,   .hit_chance = 0.015, .height = .mid },
    .{ .tag = .hand,  .side = .right,  .hit_chance = 0.015, .height = .mid },
    .{ .tag = .foot,  .side = .left,   .hit_chance = 0.015, .height = .low },
    .{ .tag = .foot,  .side = .right,  .hit_chance = 0.015, .height = .low },
    // ... other major parts
    // No finger, thumb, toe entries - expanded from parent
};
```

### Child Weight Tables (Per Species)

```zig
const HumanoidChildWeights = struct {
    pub fn hand() []const ChildWeight {
        return &.{
            .{ .tag = .hand,   .weight = 0.80 },  // hand proper
            .{ .tag = .finger, .weight = 0.15 },  // fingers (pooled or per-finger)
            .{ .tag = .thumb,  .weight = 0.05 },
        };
    }

    pub fn foot() []const ChildWeight {
        return &.{
            .{ .tag = .foot, .weight = 0.85 },
            .{ .tag = .toe,  .weight = 0.15 },
        };
    }

    pub fn head() []const ChildWeight {
        return &.{
            .{ .tag = .head, .weight = 0.70 },
            .{ .tag = .eye,  .weight = 0.10 },
            .{ .tag = .ear,  .weight = 0.08 },
            .{ .tag = .nose, .weight = 0.07 },
            .{ .tag = .neck, .weight = 0.05 },  // if neck is child of head
        };
    }
};
```

### Expansion Logic

```zig
fn expandStance(
    comptime src: []const ExposureEntry,
    comptime body_plan: []const PartDef,
    comptime child_weights: type,
) []const ExposureEntry {
    comptime {
        var result: []const ExposureEntry = &.{};

        for (src) |entry| {
            // Check if this part has children NOT in src
            const children_in_src = hasChildrenInList(entry.tag, src, body_plan);

            if (!children_in_src) {
                // Look up child weights for this part type
                if (getChildWeights(child_weights, entry.tag)) |weights| {
                    // Expand: split hit_chance among parent and children
                    for (weights) |cw| {
                        result = result ++ .{ExposureEntry{
                            .tag = cw.tag,
                            .side = entry.side,
                            .hit_chance = entry.hit_chance * cw.weight,
                            .height = entry.height,
                            .facing = entry.facing,
                        }};
                    }
                } else {
                    // No expansion defined - keep as-is
                    result = result ++ .{entry};
                }
            } else {
                // Children explicitly listed - no expansion
                result = result ++ .{entry};
            }
        }

        return result;
    }
}
```

### Detection Rule

A part expands to children when:
1. The part has children in the body plan
2. Those children are *not* explicitly listed in the stance source

**Example - torso doesn't expand:**
```zig
// If stance includes:
.{ .tag = .torso, ... },
.{ .tag = .abdomen, ... },  // child of torso, explicitly listed
// Then torso does NOT expand - children are authored
```

**Example - hand expands:**
```zig
// If stance includes:
.{ .tag = .hand, ... },
// And no .finger or .thumb entries
// Then hand DOES expand using HumanoidChildWeights.hand()
```

### Expanded Result (Static)

```zig
// standing_frontwise after comptime expansion:
const standing_frontwise = [_]ExposureEntry{
    // Head expanded:
    .{ .tag = .head, .side = .center, .hit_chance = 0.070, .height = .high },
    .{ .tag = .eye,  .side = .left,   .hit_chance = 0.005, .height = .high },
    .{ .tag = .eye,  .side = .right,  .hit_chance = 0.005, .height = .high },
    .{ .tag = .ear,  .side = .left,   .hit_chance = 0.004, .height = .high },
    .{ .tag = .ear,  .side = .right,  .hit_chance = 0.004, .height = .high },
    .{ .tag = .nose, .side = .center, .hit_chance = 0.007, .height = .high },
    .{ .tag = .neck, .side = .center, .hit_chance = 0.005, .height = .high },

    // Hand expanded:
    .{ .tag = .hand,   .side = .left, .hit_chance = 0.0120, .height = .mid },
    .{ .tag = .finger, .side = .left, .hit_chance = 0.0023, .height = .mid },
    .{ .tag = .thumb,  .side = .left, .hit_chance = 0.0008, .height = .mid },
    // ... right hand same pattern

    // Torso not expanded (abdomen listed separately):
    .{ .tag = .torso,   .side = .center, .hit_chance = 0.30, .height = .mid },
    .{ .tag = .abdomen, .side = .center, .hit_chance = 0.15, .height = .mid },

    // ...
};
```

### Benefits

- **Compact authoring**: Only specify major parts per stance
- **No runtime branching**: Full resolution at comptime
- **Species-specific**: Each blueprint has its own child weight tables
- **Explicit control**: Override by listing children in stance source

## Open Questions

1. **Enum vs f32 for height**: Enum is simpler but loses attack distribution gradients. Continuous enables richer targeting math but adds complexity.

2. **Flexible parts**: Partially addressed by arm_contribution - hands/arms vary based on technique rather than needing separate stance definitions.

3. **Mirror implementation**: `dominant_side` + `Facing.leadSide()` handles this at synthesis time.

4. **Defense coverage**: Defense technique contributes arm height/extension; body stance can be separate footwork or implied. Coverage emerges from synthesized exposure.

5. **Stamina cost for defense adjustment**: Could be derived from delta between current and target body_contribution values.

6. **Stance terminology**: Research HEMA/fechtbuch terms for flavor (separate task).

7. **Conflict detection**: How strict? Prevent invalid pairings, or allow with penalties?

8. **Synergy bonuses**: Worth tracking explicitly, or let the math handle it?

9. **Angle momentum**: Should repeated same-direction movement grant easier angle gain? Defender "spinning" to track?

## Non-Humanoid Examples

**Ooze:**
```zig
const ooze_blob = StanceDefinition{
    .name = "amorphous",
    .exposures = &.{
        .{ .tag = .core,    .side = .center, .hit_chance = 0.80, .height = .low },
        .{ .tag = .nucleus, .side = .center, .hit_chance = 0.20, .height = .low },
    },
};
// All low, simple anatomy, no stance changes
```

**Centaur (front-facing):**
```zig
const centaur_front = StanceDefinition{
    .name = "centaur_front",
    .exposures = &.{
        // Human upper body - high/mid
        .{ .tag = .head,       .side = .center, .hit_chance = 0.08, .height = .high },
        .{ .tag = .torso,      .side = .center, .hit_chance = 0.20, .height = .mid },
        // ...arms at mid...

        // Horse body - low/mid
        .{ .tag = .horse_body, .side = .center, .hit_chance = 0.35, .height = .low },
        .{ .tag = .foreleg,    .side = .left,   .hit_chance = 0.05, .height = .low },
        .{ .tag = .foreleg,    .side = .right,  .hit_chance = 0.05, .height = .low },
        // ...etc
    },
};
```
