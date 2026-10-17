# Grain sacks: separate sacks, push, tear and spill

Status: planned ([ADR 0062](../adr/0062-destructible-grain-sacks.md), proposed 2026-10-17; epic **R-2188**). Nothing below is built; today the brewer's hall shows the baked `obj.malt_sack_pile` model.

Scope: grain and flour sacks indoors as separate props in several states, pushed and knocked over by Kalev, torn by an edged blow so the grain spills and stays spilled. Out of scope in v1: carrying a sack, owner reactions or a property-damage rule, refilling and sweeping, sacks outdoors and on carts, other destructible props.

## Planned behavior

- **Sack kit.** One GLB per state: closed tied, open with grain, half-empty slumped, torn and emptied, loose grain heap (small, medium, large), oak scoop. Grain is a material slot (rye, barley malt, oats, flour).
- **Placement.** Catalog objects `obj.sack_grain`, `obj.sack_grain_open`, `obj.sack_grain_half`. The household `malt` piece (`scripts/city/household_layout.gd`) becomes a group of 2-6 sacks chosen by a hash of the house and the trade. `obj.malt_sack_pile` is retired.
- **Physics.** In Kalev's current interior every sack is a sleeping `RigidBody3D` (at most 12 awake); walking nudges it, a blow knocks it over. Sacks are not solid on the logic plane.
- **Tear and spill.** The city implementation of the player strike hook (`strike_vegetation` in `scripts/city/city_map_view.gd`, called from `scripts/map/view3d/map_view_runtime_actors.gd`) finds sacks in reach. Sword, axe or knife: the sack is torn, grain pours, a heap grows. Blunt blow or fist: knocked only. An open sack on its side spills.
- **Saved state.** Torn sack IDs (house + piece index) live in `GameState` and are saved; pushed positions are not.

## Tasks

R-2188 epic; R-2189 (GS-1) art kit, R-2190 (GS-2) placement, R-2191 (GS-3) physics, R-2192 (GS-4) tear, spill and save, R-2193 (GS-5) capture and review.
