# ADR 0039: Tall grass height by use, wading drag and trail

- **Status:** Accepted (maintainer request, 2026-10-08).
- **Amends:** the "no gameplay effect" constraint of board task R-1327 (VEGR-8) for grass in the seamless city. Everything else in R-1327 (no persistence, no stealth or tracking) stays.

## Context

City meadow grass was one height everywhere and the parting around the walker was disabled in the city view. The maintainer wants grass short where people pass (roads, houses: it gets scythed), waist-high in the open, harder and slower to walk through, and visibly pushed aside by the walker.

## Decision

1. **Height by use.** `CityGrass.wildness_at` (0..1, cached per metre) is the smaller of a distance-from-road ramp (3..22 m) and a distance-from-wall ramp (2..14 m). Clump height scales `TALL_SCALE_MIN`..`TALL_SCALE_MAX` (0.55..2.7, about waist high in the open); width grows only with the square root of that.
2. **Wading drag.** `CityGrass.walk_drag_at` returns 1.0 on bare ground and short turf, down to `TALL_GRASS_DRAG` (0.5) in dense wild grass. The city scene feeds it to `Player.set_ground_drag_provider`; it multiplies the terrain speed only while walking on dry land (swimming and wading keep their own factors).
3. **Parting and trail.** The grass shader parts blades by their own height (taller blades are shoved further and laid over) and keeps the last 8 footfalls (`VegetationInteractionBuffer`, 0.45 m spacing, 4 s spring-back) so a lane stays open behind the walker. The city view now drives it (`CityMapView.update_grass_interaction`).

## Alternatives

- Per-blade collision or a heightfield simulation: too costly for the near tier's instance count. Rejected.
- A flat slowdown by surface type: ignores the visible height, so what the player sees would not match what slows them. Rejected.

## Consequences

Crossing open meadow takes up to twice as long as using roads, which supports the road network. Drag applies only in `reval_city`; district maps are unchanged. NPCs do not part the grass or slow down yet (follow-up).
