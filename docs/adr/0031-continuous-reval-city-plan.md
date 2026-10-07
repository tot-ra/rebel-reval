# ADR 0031: Reval as one continuous, georeferenced city plan

**Reference:** maintainer request 2026-10-07 (session): make Tallinn's districts and nearby
maps seamless (The Witcher 3 Novigrad, KCD2, RDR2 as references); redo the Reval map at
high level with historically accurate streets, terrain elevation, walls and towers, Toompea
at its real height, Pikk jalg, Lühike jalg, Viru and Vene; enter most buildings with
matching inside and outside dimensions; consistent wind on flags and ropes; sewers,
barracks, food, rain run-off, movement of goods and security shaping the plan; "if you
need to change from square tiles to a better system, you can do that".

Builds on [ADR 0023](0023-terrain-relief-as-gameplay.md) (relief),
[ADR 0028](0028-seamless-building-interiors.md) (in-place interiors) and
[ADR 0029](0029-natural-reval-maps-and-larger-coast.md) (natural Reval). Changes the
delivery path of [ADR 0019](0019-seamless-contiguous-location-streaming.md) and
[ADR 0026](0026-streets-as-authored-network.md) for Reval only.

## Status

**Accepted, Artjom Kurapov (maintainer), 2026-10-07.** Implemented as a playable preview
(main menu "Reval (seamless)"). The equivalent-cost scope removal below and the use of
ODbL-licensed OpenStreetMap data were both confirmed by the maintainer on 2026-10-07. The
playable Lower Town slice keeps running on its district map until its quest anchors are
re-homed onto the plan.

## Context

- The ten `reval_outdoor` maps are rectangles on a cell grid placed side by side. They do not
  resemble Reval's oval wall circuit, Toompea stands on the same plane as the Lower Town
  (`docs/reports/images/map_audit/reval_district_alignment.png`), and every crossing is a
  scene change. Seam streaming (ADR 0019) is flag-off because one district alone exceeds
  its node and memory caps (15,088 nodes, 602 MiB, 4.7 s mount for `lower_town_slice`).
- Grid rectangles cannot hold angled or irregular houses, and the street primitive proposed
  in ADR 0026 is orthogonal-only.
- Tallinn's medieval street plan survives almost unchanged, OpenStreetMap carries the
  streets, plot footprints, surviving towers, wall fragments and the Toompea cliff lines, and
  EU-DEM gives the terrain trend. The repository already holds the dated 1343 research
  (`history/dossiers/topography/walls-gates-towers.md`, the harbour and shoreline dossiers,
  `docs/data/reval_street_register.json`, `RevalFortificationRegistry`).

## Decision

1. **One plan, metric and georeferenced.** Reval is authored as one vector plan in local
   metres (origin at the forum, x east, y south) and compiled to world units (0.87 m). The
   compiler `tools/city/build_reval_city_plan.py` merges a trimmed OSM extract, EU-DEM
   samples and a hand-authored 1343 overlay (`tools/city/reval_1343_overlay.json`) into
   `content/world/reval_city/` (plan, heightfield, surface splat). It is deterministic and
   has a `--check` mode.
2. **History overrides geography.** The overlay is where 1343 wins: the wall circuit runs
   through dated anchors with a state per curtain (stone, unfinished, timber); only towers
   standing in 1343 are built; the eight mid-century gates with their states; the 1343
   shoreline (1.4 m post-glacial uplift, post-1840 harbour fill removed); the Härjapea
   stream; the partly dry S/E ditch; the forum without a well; modern streets and later
   wall breaches are excluded or cut back at the curtain. Every record keeps a confidence
   label from `docs/CANON.md`.
3. **Terrain is a heightfield, not tiles.** Toompea is an authored limestone table on the
   DEM trend (cliffs north and west, the steep east face carrying the walled Pikk jalg and
   the Lühike jalg steps, a gentler south slope). Streets, yards, beaches and fields are
   splat weights on one continuous mesh.
4. **Buildings are footprints.** Each building is its plot polygon at any angle and of any
   shape, with a ridge on one of its own axes (gable to the street on near-square plots).
   Enterable houses are built with an interior inset by the wall thickness and a door gap,
   so the inside matches the outside; the roof lifts while Kalev is inside.
5. **One seamless scene.** The whole plan runs as `scenes/world/reval_city/reval_city.tscn`:
   logic collision from the same plan, one terrain, chunk-merged building meshes, distance
   culling for vegetation. Distant regions (Saaremaa, Padise, ...) keep their travel
   transitions (ADR 0027 and AGENTS scope are unchanged).
6. **One wind.** Flags, hoist ropes, trees, grass, smoke, clouds and water read the same
   world wind vector (`MapViewMaterials.apply_world_wind`), checked by
   `tools/verify_wind_direction.gd`.

### Equivalent-cost scope removal (confirmed 2026-10-07)

For Reval's outdoor area this plan replaces, and the following rows are retired rather
than delivered: per-district relief re-authoring of the `reval_outdoor` maps (R-976 Reval
slices), district street re-authoring UF-05..UF-07 on the grid, coastal growth of the grid
maps (R-950, CO-03 footprints) and the `reval_outdoor` seam phases of ADR 0019
(R-977..R-980). ADR 0026's orthogonal street primitive is no longer needed for Reval.
Existing quest content stays on `lower_town_slice` until its anchors are re-homed onto the
plan (a follow-up task per quest), so nothing playable is removed by this ADR.

## Alternatives

- **Keep district grids and turn streaming on.** Measured residency already breaks the caps;
  seams stay visible and rectangles cannot follow the wall or the klint.
- **Grow one giant grid map.** About 1.3 million cells at this scale; the per-cell terrain,
  navigation and validation cost does not scale, and buildings still could not rotate.
- **Hand-author every street and plot.** Weeks of work to approximate what the surviving
  street plan and plot boundaries already record; kept only for the 1343 overlay.

## Consequences

- 2026-10-07 (maintainer direction): the city became the game's Reval rather than a
  preview. Start runs forge → city; every old Reval district destination (forge
  door, interior exits, district fast travel, returns from distant regions) is
  redirected to a city spawn by `CityTravel`, and the menu entry was removed. The
  district scenes stay in the repository, unreachable, until their quests move.
- OSM data is ODbL: the trimmed extract and the derived plan carry the attribution and stay
  available under ODbL (`docs/THIRD_PARTY_NOTICES.md`, `CREDITS.md`). EU-DEM needs attribution only.
- Plot footprints are modern survivals of medieval plots; individual houses are a
  plausible composite, not a 1343 survey. The overlay is the place to correct them.
- The city preview has no NPCs, quests, saves or swimming yet; see the limits in
  [`docs/SYSTEMS/SEAMLESS_CITY.md`](../SYSTEMS/SEAMLESS_CITY.md).
- Verification: `python3 tools/city/build_reval_city_plan.py --check`,
  `python3 -m unittest tests.python.test_build_reval_city_plan`, the Godot test
  `tests/godot/test_city_plan.gd`, and the walk acceptance
  `tools/godot_render.sh --resolution 1600x900 res://tools/capture_reval_city_walk.tscn`.
