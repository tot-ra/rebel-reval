# ADR 0057: Lightning strikes as a gameplay hazard

**Reference:** maintainer request 2026-10-16 (session): lightning in a thunderstorm must be able to
strike nearby - a tree, a building or a person - not only be a sky effect. Epic **R-2151**
(tasks R-2152..R-2156). Feature page: [`SKY_ATMOSPHERE.md`](../SYSTEMS/SKY_ATMOSPHERE.md#lightning-strikes).

## Status

**Accepted** by the maintainer on 2026-10-16 ("approve as is" on the five decisions below).

## Context

- Lightning already exists as presentation: `SkyWeather3D` (`scripts/map/view3d/sky_weather_3d.gd`)
  fires strikes only from mature storm cells, on its own deterministic RNG stream, and picks a
  ground point for the 40% cloud-to-ground strokes. The point is saved with the weather state.
- [`SKY_ATMOSPHERE.md`](../SYSTEMS/SKY_ATMOSPHERE.md) declares every sky layer presentation only.
  This ADR is the exception for ground strokes landing near the player.
- The death screen already picks an illustration by the fatal hit's damage type
  (`slash`, `blunt`, `pierce`, `neutral`).
- Trees are procedural MultiMesh batches with no saved per-plant state
  ([`LIVING_VEGETATION.md`](../SYSTEMS/LIVING_VEGETATION.md)).

## Decision

1. **Targeting (realism).** Strikes still come only from a mature storm cell. When a ground
   stroke lands within about 600 m of the player, it snaps to the best target near its point,
   weighted by height: spires and towers, then lone trees, then buildings, then a person in the
   open, then bare ground. A close strike (under 150 m) happens about 1-3 times per storm. A
   direct hit on the hero is very rare and only when he is outdoors in the open or under a lone
   tree; indoors or under a roof he is never struck. Every draw uses the lightning RNG, so a save
   reproduces the next strike.
2. **Tree.** A struck tree catches fire (flames and smoke for about 1-3 minutes, shorter in rain),
   then stays charred and leafless for good. The charred state is saved per tree.
3. **Building.** A scorch mark and a burst of sparks; on a thatch or shingle roof a small fire that
   dies out by itself. Fire spreading between buildings is out of scope and needs its own ADR.
4. **Person.** A direct hit kills in about 70% of cases, otherwise deals heavy damage; a strike
   within about 10 m (ground current) deals damage and a stun. Anonymous citizens can die. Named
   and quest NPCs are only injured, so stories never break. A lightning death is not the hero's
   guilt.
5. **Hero.** A direct hit kills Kalev and opens the death screen with a new `lightning`
   illustration. A near strike deals damage, a stun and a short ear ringing.

## Consequences

- One strike event (kind, position, target id) feeds the hero, citizens, trees and buildings, so
  each consumer is a small separate task.
- GameState gains saved charred-tree keys; trees become the first plants with saved state.
- New art: `assets/UI/death/death_lightning.png` with its `assets/SOURCES.csv` row.
- Thunder timing to strike distance stays out of scope, as before.
