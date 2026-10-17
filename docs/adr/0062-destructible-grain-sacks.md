# ADR 0062: Separate grain sacks that can be pushed and torn open

**Reference:** maintainer request 2026-10-17 (session, screenshot of a brewer's hall): the sacks
should look more realistic, maybe with physics; they should be separate models so any number of open
or closed sacks can be placed; a sword blow should tear a sack and spill the grain. Board: epic
**R-2188** (GS-0). Feature page (planned): [`GRAIN_SACKS.md`](../SYSTEMS/GRAIN_SACKS.md).

## Status

**Proposed (2026-10-17), awaiting maintainer approval.** The decisions below are the recommended
defaults; the maintainer did not answer the scoping question in the session, so each one is open to
change before GS-1..GS-4 start.

## Context

- The only grain sacks indoors are `obj.malt_sack_pile`: one baked GLB from
  `tools/generate_malt_sack_pile.py` (1624 triangles, 512 px albedo only, two closed sacks, one open
  sack, a scoop). `HouseholdLayout` places it as the `malt` piece in the halls of brewers, alewives
  and maltsters. It reads as low-poly and toy-like and cannot be recomposed.
- `obj.sack_grain` exists in the object catalog with `model: missing`; R-1373 (HOMEOBJ-7) and R-206
  (cart loads) both want a single grain sack.
- Every player swing already calls `strike_vegetation(...)` on the view
  (`scripts/map/view3d/map_view_runtime_actors.gd`); the seamless city implements it as a no-op
  (`scripts/city/city_map_view.gd`). A sack hit can use the same call, so no new combat system.
- Nothing in the world is destructible today, and no world prop moves under physics. Logic and
  collision live on the 2D logic plane; the 3D view only presents it.

## Decision

1. **A sack kit, one GLB per state.** A new deterministic Blender generator builds: closed tied sack,
   open sack with a rolled collar and visible grain, half-empty slumped sack, torn and emptied sack,
   loose grain heap (three sizes), and the oak scoop alone. Realism comes from a sculpted cloth
   surface (gathered folds under the tie, sag over the grain, seams) baked to 1K albedo, normal and
   ORM, about 3-6k triangles per sack. Grain contents are a material slot, so rye, barley malt, oats
   and flour share the meshes.
2. **Catalog and placement.** The catalog gains `obj.sack_grain` (closed, gets its model),
   `obj.sack_grain_open` and `obj.sack_grain_half`. The household `malt` piece becomes a sack group:
   2-6 sacks, closed/open/half chosen by a hash of the house and the trade (a maltster or brewer keeps
   one open sack with the scoop in it). Authors can place any single sack anywhere. `obj.malt_sack_pile`
   is retired.
3. **Physics only near Kalev.** In the interior Kalev is in, each sack is a sleeping `RigidBody3D`
   with its catalog mass (22-50 kg). Kalev's walk nudges it and a blow knocks it over. At most 12
   bodies are awake; every other sack is a static mesh. Sacks stop counting as solid on the logic
   plane (like stools), so a pushed sack never disagrees with navigation. No cloth simulation:
   `SoftBody3D` was judged too costly and unstable for dozens of sacks.
4. **An edged blow tears a sack.** The city's strike hook finds sacks in reach and facing. A sword,
   axe or knife tears one: the mesh swaps to the torn sack, grain pours as a short particle stream,
   and a heap grows on the floor. A blunt blow or a fist only knocks the sack. An open sack knocked
   onto its side spills without tearing.
5. **Torn stays torn.** The set of torn sack IDs (house + piece index) is stored in `GameState` and
   saved, so heaps are still there after a reload. Pushed positions are not saved: an intact sack
   returns to its authored spot. Nobody refills or sweeps in v1.
6. **No consequences in v1.** Tearing a sack is not yet theft, guilt or a crime. Owner reactions and
   a property-damage rule are a follow-up task.

## Alternatives considered

- **Keep the baked pile and only re-texture it:** does not give separate sacks or any interaction.
- **Meshy-generated sacks:** more photographic at first sight, but the open, half and torn states
  would not match each other and the topology is hard to deform. The Blender kit can still borrow a
  Meshy or Leonardo texture.
- **Soft-body cloth:** best looking up close, but expensive and unstable in Godot with many bodies.
- **Visual-only spill, nothing saved:** simpler, but a torn sack that heals after a reload breaks the
  deterministic-world rule.

## Consequences

- Board: R-2188 epic; R-2189 (GS-1) art kit (also delivers R-1373's grain sack), R-2190 (GS-2) placement, R-2191 (GS-3)
  physics, R-2192 (GS-4) tear, spill and save, R-2193 (GS-5) capture and review.
- Asset freeze P0-040: GS-1 names its files and adds `assets/SOURCES.csv` rows.
- First destructible prop and first physics-driven world prop; later barrels, baskets or crates can
  reuse the same strike-hook and torn-ID pattern, but each needs its own task.
- Not done in v1: carrying a sack, owner reactions, refilling and sweeping, sacks outdoors and on
  carts (R-206 can reuse the closed sack model as a static mesh).
