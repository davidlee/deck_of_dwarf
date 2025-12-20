# cardigan: an SDL game in zig

There's fuckall here, I just deleted everything. 

But, it's a potentially useful fuckall if you want a working shell to build on: zig, SDL3, a FSM library and a few other amenities build nicely under NixOS (there's a flake and everything).

# design

I'm writing a card game - a deck building dungeon crawler.

this is mostly an excuse to stretch my skills using Zig (and learn SDL, etc) on something fun.

think along the lines of slay the spire / darkest dungeon, but with distinctly more "crunch" - dwarf fortress style over the top simulation of injury & inventory, etc.

I want to keep the scope reasonable for a side project, but ...

--
so i was toying with a DF style inventory & injury system - which I have sketched out (the kind of system that handles realistic armour layering, wearing goggles around your neck or helmet visor up/down, and chunky rings that can be worn under leather gauntlets but not nitrile gloves) but .. TBD if that's fun. I'm in the process of exploring / modelling a lot of systems to select the ones which might make a game that's fun to play and tractable to build.

on RNG - I have entertained the idea of using an event sourced approach - it might be interesting to unpack whether there are any potential advantages & how one might deal with randomness.

first though, i'll pin down the things I think are known:

pub const StatBlock = struct {
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
player stats are important; sometimes (often) we take the average of 2 rounded down - eg bow accuracy = acuity+agility. I want to try to keep them balanced in utility, and to provide as many paths to good builds as possible. leaning classless, not sure if skills are required yet - probably moreso "moves" in the form of your deck of action cards. 

Spell list, inventory is a set of cards; equip sceen is a set of cards laid out on on a model of physiology.

A dungeon is a graph of encounter & other nodes. An encounter node = a card - when applied you draw a set of monster cards (and maybe other - environment, situation, treasure). Combat is heavily based around action economy - each 'round' represents 1 second and often neither players or monsters will act in a turn; actions have a cost expressed in both seconds (rounds to complete) and often endurance or mana; they can be interrupted. Knowing what the opponent is doing is probably a check (dice roll against say arcana / soldiery - acuity + intuition)?

we'll have conditions (blind, deaf, paralysed) and DoT effects; probably a lightweight event system (you can use SDL user def events but I gather best to separate, for performance. Experience / progression is largely a case of collecting better cards but also getting better at things you do (especially on failure). Maybe hirelings (again, cards) are important, though not all fight - i figure there might be torchbearer elements and as soon as *someone* isn't holding a torch or lantern, you're cooked. You're managing something between a party and an expedition loot caravan. There's probably a risk/reward "do i press on" tension and adventure / village cycles.

I was leaning towards persistent, realistic, gritty injuries - individual wounds (blunt/pierce/slash/burn/...) to bone, muscle, arteries, nerves; serious enough and you cant' run or hold a sword. Magical healing, but not on tap. Simple factions have potential (alertness, hostility, etc); not intending modelling map tiles or complex non-card world state though.

Cards: came here to say I want to riff on the core card data model. Identify the right set of basic categories. I think the most interesting game model is probably something like Balatro where cards are not just clumps of numbers, but rules / tags / effects which interact in interesting and complex ways. Which also sounds a lot harder to implement than adding up numbers ...

--

You’re converging on the right “north star”: **cards as rules that transform state** (Balatro-ish), with a simulation core that stays deterministic and debuggable. The trick is picking *a small number of powerful primitives* so you get emergent complexity without writing bespoke code for every card.

Below is a Zig-friendly model that fits your constraints: **not ECS, not OOP**, composition-heavy, data-oriented, deterministic, and still expressive enough for “cards as rules”.

---

## 0) Quick note on `packed struct` for stats

`packed struct` + `f32` is usually not what you want. Packed forces unaligned loads/stores (can be slower, can trap on some targets, and is generally a “bit-level layout” tool). If you want cache friendliness, prefer normal struct (it’s already compact enough), or SoA if you’re iterating many actors.

If you want “stable serialization layout”, you’ll likely do explicit encode/decode anyway.

---

## 1) Make cards mostly **data**, but with a tiny “escape hatch”

### Card = Definition + Instance

* **CardDef**: immutable content (name, art id, rules, tags)
* **CardInst**: per-run state (upgrade level, counters, bound target, “this was discovered”, durability, etc.)

This lets your “collect better cards” loop work, while still supporting roguelike-run modifiers and your “learn by failing” progression.

---

## 2) The core primitives: Events, Queries, Ops, and Modifiers

Balatro complexity comes from:

* **tags**
* **trigger timing**
* **rule stacking**
* **modifiers that hook into evaluation**

You can emulate that with four core things:

### A) Events (facts that happened)

Examples:

* `ActionStarted`, `ActionInterrupted`
* `DamageDealt`, `WoundInflicted`
* `CardPlayed`, `CardMovedZone`
* `CheckRolled`, `PerceptionSucceeded`
* `TurnAdvanced`, `SecondElapsed`

### B) Queries (read-only selectors used by effects)

Examples:

* “all enemies in melee range”
* “the action currently being charged by unit X”
* “all wounds on left arm”
* “all equipped items on hands layer stack”

### C) Ops (the only ways to mutate state)

Examples:

* `ApplyDamage`
* `InflictWound(type, body_part, severity)`
* `AddCondition(Blind)`
* `MoveCard(zone_a -> zone_b)`
* `StartAction(action_def, duration, costs)`
* `InterruptAction(reason)`

### D) Modifiers (rules that rewrite numbers / outcomes / legality)

This is the Balatro sauce.

A modifier is something like:

* “When you would apply Pierce damage, convert 25% to Bleed”
* “While wearing goggles on neck, you are not protected from gas, but you can raise them as a 0.2s action”
* “Checks using Acuity+Intuition: reroll 1 die if torchlight present”
* “Ring counts as ‘bulky’ and blocks nitrile glove slot”

Modifiers are *not effects you manually call*—they are **attached to scopes** and consulted by resolvers.

Scopes could be:

* global (run-wide)
* party
* unit
* body-part
* item/equipment
* card-in-hand / card-in-play
* encounter node (environmental modifiers)

---

## 3) Card rules as “Triggers + Effects”, with modifier hooks

A card definition becomes:

* tags (for synergies)
* a set of trigger rules:

  * `on_play`
  * `on_draw`
  * `on_second_elapsed`
  * `on_damage_dealt`
  * `on_action_started`
  * etc.
* each trigger rule has:

  * condition (optional query/predicate)
  * effect list (ops or custom)

This gives you: “cards as rules”, not “cards as numbers”.

### Zig shape (sketch)

You’ll likely end up with something like:

```zig
pub const TriggerKind = enum {
    OnPlay,
    OnDraw,
    OnSecond,
    OnEvent, // parameterized by EventKind
};

pub const Effect = union(enum) {
    Op: Op,                 // the boring, composable ops
    If: IfEffect,           // condition + then/else
    ForEach: ForEachEffect, // query + effect
    Custom: CustomEffectId, // escape hatch
};

pub const Rule = struct {
    trigger: Trigger,
    predicate: ?Predicate,
    effects: []const Effect,
};

pub const CardDef = struct {
    id: CardDefId,
    tags: TagSet,
    rules: []const Rule,
    // plus UI fields, costs, etc.
};
```

A *Predicate* can be a small expression tree (“target has Condition.Blind and you have Torchlight”).

You can keep the expression language small and still get big interactions.

---

## 4) The “Modifier Pipeline”: how Balatro-ish stacking works

To avoid bespoke logic everywhere, define a few “calculation points” that always go through the same pipeline:

* `ComputeCheckDifficulty`
* `ComputeHitChance`
* `ComputeDamagePacket`
* `ComputeActionTime`
* `CanEquip(item, slot, current_layers)`
* `ComputeVisionRange`
* `ComputeInterruptChance`
* `ComputeLootCapacity`

Each is a function like:

1. start with base value (from stats + defs)
2. gather modifiers from relevant scopes
3. apply them in a deterministic order
4. return final value and (optionally) an explanation trace for UI/debug

This is where tags + rules become “complex but tractable”.

### Deterministic ordering

You need a stable rule for applying modifiers:

* by scope priority (global -> party -> unit -> equipment -> wounds -> temporary buffs)
* then by source id (CardDefId / ItemDefId)
* then by acquisition order if needed

This makes replays and debugging sane.

---

## 5) RNG + event sourcing: what you gain, and how to do it cleanly

### Advantages of event-sourcing in your game

* **replay/bug reproduction**: “here’s the seed + command list; watch it happen”
* **undo / what-if**: AI simulations, tool-assisted balance
* **postmortems**: show the player *why* something happened
* **networking** (if you ever do it): lockstep becomes feasible

### The RNG gotcha

If your event log only records “high-level events” but randomness is used inside resolvers, you can get divergence if:

* code changes iteration order
* you add a new random call somewhere
* you change a data structure traversal order

The fix is: **make randomness itself an event**, or make it an explicit resource with recorded draws.

#### Option A: Record RNG draws as events (recommended)

When resolver needs randomness, it requests a draw, and you emit:

* `RandomDraw { stream: Combat, kind: D20, value: 13 }`

Then all randomness is replayed exactly, independent of code changes (as long as you still consume the same “draw events” for the same requests). Even if logic changes, you’ll at least detect mismatch cleanly.

To keep it robust, don’t just store `value`. Store also a **draw id** / **purpose**:

* `purpose = "Check:IdentifyAction intent unit#12"`

So if your code tries to draw for a different purpose, you can surface a helpful desync message in dev builds.

#### Option B: Counter-based RNG (works, but easier to accidentally break)

If you use a counter-based PRNG where each system draw is keyed by `(turn, unit_id, purpose_hash, n)`, you can avoid ordering sensitivity. But it’s more complex to design and still easy to mess up if “purpose” isn’t consistent.

**Option A** is simpler and *very* nice for a sim-heavy roguelike.

### Streams

Use multiple RNG streams so that adding a cosmetic random call doesn’t alter combat outcomes:

* `rng_combat`
* `rng_loot`
* `rng_mapgen`
* `rng_ai_noise`

If you record draws, you still keep streams because it improves reasoning and reduces log noise.

---

## 6) Inventory + injury layering: keep it “deep but bounded”

Your DF-style equipment layering can be fun *if*:

* it creates **meaningful choices**
* it doesn’t explode UI/turn time
* it doesn’t force constant micro-adjustments

Two patterns to keep it tractable:

### A) Treat equip as a constraint-satisfaction problem with small local rules

Instead of per-item bespoke checks, define:

* Slots with layers: `Skin`, `Under`, `Armor`, `Over`, `Accessory`
* Each item has:

  * coverage set (body parts)
  * thickness / bulk
  * allowed layers
  * conflicts/tags (e.g. `requires_underlayer_free`, `blocks_gloves`)
* Then `CanEquip()` runs through a generic constraints check.

This also plugs nicely into your modifier pipeline:

* “ring is bulky” is a modifier that changes `bulk_in_hand` or `layer_compatibility`.

### B) Injuries as data + effects (not constantly-simulated anatomy)

You can absolutely do “bone/muscle/artery/nerve” if you avoid simulating physiology every tick.

Make injuries:

* a record: `{ type, body_part, tissue, severity, tags }`
* plus rule hooks:

  * modifies stats/actions (pipeline modifiers)
  * generates periodic events (bleed tick, pain spike)
  * gates actions (can’t wield two-handed weapon)

Then you only “do work” when:

* an injury is created/updated
* an action is attempted
* a periodic tick happens

That keeps CPU and code complexity sane.

---

## 7) Picking “basic categories” for cards (a useful minimal set)

Here’s a set of categories that tends to produce emergent interaction without bloat:

### Action Cards (spend time + resources)

* attacks, spells, maneuvers, interrupts, stances, utility actions
* key property: **action-time + interruptibility**

### Passive Rule Cards (always-on modifiers)

* “relics”, “traits”, “stances” if persistent, hireling auras, injuries as cards even

### Reaction Cards (triggered by events)

* “when you are targeted…”
* “when an ally takes damage…”
* “when second elapses during your action charge…”

### Encounter/Environment Cards (scope modifiers)

* darkness, cramped corridor, deep water, toxic spores
* these are great because they reshape the whole combat puzzle

### Resource/Logistics Cards

* torches, food, rope, pack mule, medical kit
* these create the press-on tension you described

### Meta-Progression Cards

* “learned move” variants, upgraded forms, training scars, reputations
* you can represent learning on failure by swapping/transforming cards or adding passive rules

Under the hood, all of these are the same thing: **rules attached to a scope**. The category is mostly UX.

---

## 8) How to keep “cards as rules” implementable

You’re right: it’s harder than adding numbers. The way to make it implementable is:

1. **Lock the mutation surface area** (Ops only)
2. **Centralize calculations** (modifier pipeline)
3. **Keep the expression language tiny** (Predicate + Query)
4. **Allow a small escape hatch** (CustomEffectId) for rare “bespoke” mechanics

If you do that, you can ship with mostly-data content and only a few hardcoded effects.

---

## A concrete next step that will clarify everything fast

Build (just in code, no UI needed) a tiny vertical slice of the rules engine:

* 1 player, 1 enemy
* 3 actions (Strike, Aim, RaiseVisor)
* 2 passives (Torchlight, GogglesNeck)
* 2 conditions (Blind, Bleeding)
* 1 check (“identify opponent action”)
* RNG recorded as `RandomDraw` events
* modifier pipeline points: `ComputeVision`, `ComputeHitChance`, `CanEquip`

Once that exists, you’ll know:

* whether event sourcing feels good
* whether your modifier system is expressive enough
* how painful “cards as rules” really is (usually it’s fine if Ops+pipeline are solid)

If you want, paste your current card struct sketch (or even just the fields you *think* a card needs), and I’ll propose a “minimal but powerful” Zig data model that supports:

* triggers
* predicates/queries
* stacking modifiers
* deterministic event log + RNG draw events
  without turning into an ECS or a DSL you hate maintaining.

---
So yeah, a simple early prototype of this game probably doesn't need goggles, visors, non-humanoid physiology templates, layering rules, any representation of combat situation beyond showing the cards and a log, a "magic system", skills, progression (other than cards as loot), more than one combat / opponent, vision calculation ...

what it'd want to pin down is how player stats, equipped weapon, action cards & the time/endurance economy come together to produce attacks; how players can make strategic choices (when to attack / defend; conserve energy vs push to exhaustion; deploy an exhaustible card).

One critical question is how much of a feature randomness is in basic attack / defence, eg:
- none - it's all about allocation of resources to attack / defence; any undefended attacks are deterministic
- all - each attack is a "roll" which might succeed or fail; damage is a random range

I might try the deterministic route first.

