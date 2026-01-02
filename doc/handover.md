# Handover Notes

## 2026-01-02: Test Coverage Backfill

- `stats.Resource`: 5 tests covering commit/finalize, uncommit, spend, tick, reset
- `AgentPair.canonical`: assertion for self-engagement (a==b), test for order invariance
- `Play.addReinforcement`, `TurnState.addPlay`: overflow error tests

---

## 2026-01-02: Focus System Phase 1.5 Complete

### Implemented

**1.5: Turn State Structs**
- Added `Play` struct with reinforcements buffer, stakes escalation, modifiers
- Added `TurnState` struct tracking plays and focus_spent
- Added `TurnHistory` ring buffer (4 turns) with push/lastTurn/turnsAgo
- Added `AgentEncounterState` wrapping current turn + history
- Added `Encounter.agent_state` hashmap with `stateFor()` accessor
- Player and enemy states auto-initialized in `Encounter.init()`/`addEnemy()`
- Note: BoundedArray removed in Zig 0.15, replaced with buffer+len pattern

### Key Files Changed
- `combat.zig` - Play, TurnState, TurnHistory, AgentEncounterState, Encounter.agent_state

---

## 2026-01-02: Focus System Phase 2 Complete

### Implemented

**2.1: TagSet Extension**
- Added `manoeuvre` tag to `TagSet` packed struct
- Updated bitcast size from `u12` to `u13`

**2.2: Draw Filtering**
- Added `TagIterator` struct for iterating cards by tag
- Added `Deck.countByTag()` - count cards in draw pile matching tag mask
- Added `Deck.drawableByTag()` - iterate draw pile by tag mask
- Added 4 tests for tag filtering functionality

### Key Files Changed
- `cards.zig` - TagSet.manoeuvre, updated bitcasts
- `deck.zig` - TagIterator, countByTag(), drawableByTag(), tests

### Remaining (per design doc)
- Phase 3: Commit phase mechanics
- Phase 4: Draw decision mechanics
- Phase 5: Transform cards (Feint)

---

## 2026-01-02: Focus System Phase 1 Complete

### Implemented

**1.1-1.3: Resource System**
- Added `stats.Resource` struct with commit/spend/finalize semantics
- Replaced `Agent.stamina`/`stamina_available` with `stamina: Resource`
- Added `Agent.focus: Resource`
- Added `Cost.focus: f32 = 0`

**1.4: Encounter State Migration**
- Added `AgentPair` for canonical agent pair keys
- Added `Encounter.engagements: AutoHashMap(AgentPair, Engagement)`
- Added `Encounter.player_id`, `getEngagement()`, `setEngagement()`, `addEnemy()`
- Removed `Agent.engagement` field
- Updated `ConditionIterator` to take optional engagement parameter
- Migrated all engagement lookups to use Encounter

### Remaining (Phase 1.5 per design doc)
- `TurnState`, `TurnHistory`, `Play` structs not yet added
- `AgentEncounterState` not yet wired up

### Default Resource Values
```zig
stamina: Resource.init(10.0, 10.0, 2.0)  // default, max, per_turn
focus: Resource.init(3.0, 5.0, 3.0)
```

### Key Files Changed
- `stats.zig` - Resource struct
- `combat.zig` - Agent, Encounter, AgentPair, ConditionIterator
- `cards.zig` - Cost.focus
- `apply.zig`, `tick.zig`, `resolution.zig` - engagement lookups
- `world.zig` - Encounter init ordering
- `harness.zig` - uses `addEnemy()`
