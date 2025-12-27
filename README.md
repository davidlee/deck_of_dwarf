# DECK OF DWARF: a card game about killing Gobbo scum

This is an experimental deck-building dungeon battler written in Zig (0.15.2) with SDL3 bindings.

The game is about simultaneous disclosure, information asymmetry, and ludicrous simulated detail.

There are no health bars; only bone, tissue penetration, and vital organ trauma.

Happily, Dwarves regenerate in the presence of alcohol (although the process isn't kind to the alcohol).

Success in combat is about anticipating your opponent, carefully conserving stamina, probing and exploiting to gain an advantage, and pressing it at the right time (without over-extending) to land a decisive hit.

Everything is a card, drawn at random from your deck; but your inventory is modelled in autistic detail. Gambeson can be layered under chain; munitions plate is nearly impervious, but leaves your joints vulnerable to a rondel dagger.

Think of it as an attempt to answer the question nobody ever asked: what if Dwarf Fortress fell into a teleporter with Slay the Spire and Balatro?

  Current State: pre-alpha. No graphics; partial harness testing partially complete core systems.

1. combat.zig - Has the core structures:
- Agent - unified player/mob with balance, stamina, engagement, body, armour, weapons
- Engagement - pressure, control, position, range (our model!)
- Reach enum
- AdvantageAxis enum
- Comments with the vulnerability logic
2. weapon.zig - Weapon modeling:
- Offensive struct with accuracy, speed, damage, penetration, defender_modifiers
- Defensive struct with parry, deflect, block modifiers
- Template with swing, thrust, defence, ranged options
- Grip and Features for weapon capabilities
3. armour.zig - Complete armor system:
- Material (resistance, threshold, hardness, thickness)
- Totality (gap chance)
- Stack (runtime lookup by body part → layers)
- resolveThroughArmour - full damage resolution through layers
- Events for deflection, gap found, layer destroyed, etc.
4. cards.zig - Card/technique definitions:
- Technique with ID enum, damage, difficulty, defensive multipliers
- Stakes enum (probing, guarded, committed, reckless)
- Predicate with weapon_category, weapon_reach, range, advantage_threshold
- Exclusivity for technique slot usage
5. apply.zig - Command/event handling:
- CommandHandler.playActionCard - validates and plays cards
- EventProcessor.dispatchEvent - handles events
- EffectContext and TechniqueContext (partially implemented)