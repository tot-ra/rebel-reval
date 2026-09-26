# CO-09: Saaremaa becomes a region you can walk, not a corridor

Board row: **R-956**. Priority: high. Depends on: CO-04. **Carries a scope-change ADR** (footprint).

## Player-facing goal

Arriving from the coastal landing, the player can actually explore Saaremaa: walk the north beach,
turn inland across open alvar, reach the muster camps, circle the Kaali crater and follow the road
toward Pöide and the strait, with more than one route between any two landmarks. The island reads as
a stretch of countryside, not as a narrow strip between the sea and a wall of trees.

## Why this is needed

Measured 2026-09-26 by compiling `world.saaremaa` and flood-filling `MapVerification.is_walkable_cell`:

- Footprint **104x60 cells = 90x52 m**, the smallest of the three coastal maps (Kalamaja is 144x80,
  Harbor North 160x108).
- Only **2610 cells walkable, 41.8%** of the map. The largest connected region is 2606, so the island
  is connected - it is simply small and cramped, which is exactly the reported "character is unable to
  move across its map that much".
- `forest_floor` is **25.6%** of the map and blocks. It is authored as bands that fence the player in
  on three sides: `wood.south 0 51 104 9` (the entire south edge), `wood.west 0 32 12 19`,
  `wood.east 92 44 12 7`, plus the `kaali.outer_slope` pine mass covering roughly cells
  54-87 x 25-50 in the middle of the map.
- **Zero elevation profiles**: dead flat, so the crater that is supposed to be the landmark is a
  painted rect. CO-04 fixes the profiles; this task gives them room.
- 72 props and no structures, so the obstruction is terrain and tree bands, not buildings.

## Deliverable

1. **ADR** (next free number, or an amendment to the CO-03 footprint ADR if that one is still open)
   covering the footprint growth, the coordinate shift, the regenerated fixtures and the named
   equivalent-cost scope removed in exchange.
2. `world.saaremaa` re-authored at **160x104** (139x90 m), keeping map ID `world.saaremaa` /
   `loc.world_saaremaa`, `seed=1346`, `cell_size=32`, and **every** terrain, transition, spawn, anchor
   and prop ID (`ferry_to_reval`, `ferry_to_parnu`, `road_to_poide`, `landmark_island_coast`,
   `landmark_ferry_landing`, `landmark_fisher_hamlet`, `landmark_muster_camp`, `landmark_west_camp`,
   `landmark_east_camp`, `landmark_burned_manor`, `landmark_kaali_crater`, `landmark_kaali_lake`,
   `landmark_strait_landing`, `prototype_inspection`, all 72 props).
3. Walkable area target: **>= 6000 walkable cells** and **>= 55%** of the map, with the largest
   connected region holding **>= 98%** of them.
4. The forest stops being a fence. Keep woodland as a boundary treatment but open it with at least
   **three** walkable routes through or around each band, glades, and a continuous coastal path that
   runs the full width. No blocking band may span the full map width without a gap.
5. The Kaali crater becomes a walkable landmark: a circumnavigable rim path, at least two descents
   toward the lake shore, and the crater lake kept as water. The CO-04 rim elevation carries the drama
   instead of a pine wall.
6. Route guarantee: **at least two topologically distinct routes** between each pair of
   (`ferry_to_reval` landing, `landmark_muster_camp`, `landmark_kaali_crater`, `road_to_poide`), so a
   single prop or tree cannot sever the island.
7. Decide explicitly what happens to `terrain_rects alvar.boulders stone`: either keep the paint or
   replace it with the CO-02 boulder props. Record the decision in the report; do not leave both.

## Allowed files

- `content/maps/world_saaremaa.rrmap` (+ `.uid`)
- `scripts/map/map_blueprint_registry.gd` (required anchors only, no ID renames)
- `scripts/map/definitions/outdoor/distant_location_definitions.gd` (only if size constants live there)
- `content/map_audit_manifest.json`
- `docs/adr/00NN-coastal-map-footprint.md` (new or amended), `docs/MAP_AUTHORING.md`,
  `docs/MAP_CONVERSION_PLAN.md`
- `tests/godot/test_world_saaremaa_map.gd` (new), `tests/godot/test_transition_manifest.gd`
- `tools/capture_co09_saaremaa.gd` (new)
- `docs/reports/co09_saaremaa_traversability.md`, `docs/reports/images/co09_*.png`, `TODO.md`

## Constraints and non-goals

- **No ID may be renamed or dropped.** Cells may move; IDs may not. The test enumerates all of them.
- Do not activate the map. It stays `scope=prototype active=false` until its own activation task.
- Do not add quests, NPC routines, Pöide siege content or new gameplay systems. Terrain, elevation
  hand-off and traversability only.
- Do not solve the size problem by deleting the woodland. The island must still read as wooded
  Saaremaa; it must be permeable, not absent.
- Historical claims about Saaremaa settlement stay as they are. Growing the map does not license new
  attested-looking detail; anything new inherits the existing reconstruction labelling in
  `docs/CANON.md`.
- Do not change the Reval-side transitions or `world_parnu` / `world_poide`.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_map_blueprints.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
python3 tools/verify_map_audit.py
python3 tools/verify_map_activation.py
python3 tools/verify_map_conversion_plan.py
python3 tools/verify_map_composition.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

- `test_world_saaremaa_map.gd` asserts: walkable cells >= 6000 and >= 55% of the map (baseline 2610 /
  41.8%); largest connected region >= 98% of walkable; every listed stable ID still present; every
  transition rect, spawn and anchor on a walkable cell; no blocking band spans the full map width;
  >= 3 gaps through each woodland band; a full-width coastal path exists; the crater rim is
  circumnavigable and has >= 2 descents; >= 2 distinct routes between each of the four key points
  (proved by removing the cells of route A and re-running the path search).
- Arrival check: entering at `from_reval_harbor` from `reval_harbor_north`, the player stands in the
  largest region and can reach all three transitions.
- `tools/capture_co09_saaremaa.gd` through `tools/godot_render.sh`: top-down walkability overlay before
  and after, plus gameplay-camera plates at the ferry landing, the alvar, the crater rim and the strait.

## Doc updates

ADR, `docs/MAP_AUTHORING.md`, `docs/MAP_CONVERSION_PLAN.md`, `content/map_audit_manifest.json`,
`docs/reports/co09_saaremaa_traversability.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-956 | deps: R-951 | deliverable: ADR-gated re-authoring of world.saaremaa to 160x104 raising walkable cells from 2610 (41.8%) to >= 6000 (>= 55%), opening the south/west/east woodland fences with >= 3 gaps each, a full-width coastal path, a circumnavigable Kaali rim with >= 2 descents and >= 2 distinct routes between the ferry landing, muster camp, crater and Poide road | allowed files: per docs/tasks/coast/CO-09_saaremaa_traversability.md | verify: blueprint validate, full Godot suite, map audit/activation/conversion/composition, active docs; test_world_saaremaa_map walkable, connectivity, stable-ID census, no full-width blocking band and route-redundancy assertions; arrival from reval_harbor_north reaches all three transitions; walkability overlay before/after plus ferry/alvar/rim/strait plates
```
