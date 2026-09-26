# AR-04: modular architecture kit part library

Board row: **R-962**. Priority: high. Depends on: AR-01, AR-02 (**ADR 0022 must be accepted or
explicitly approved before coding**).

## Player-facing goal

None on its own - this is the part library. Its effect is that every later AR task builds from real
architectural components, so a wall has a plinth, a storey line, a lintel and an eave instead of being
one extruded face, and two houses on the same street can share a language without sharing a silhouette.

## Why this is needed

The project has two building pipelines and neither can express a building.

- Procedural runtime: `map_view_mesh_builder_building_houses.gd`, `..._house_structure.gd`,
  `..._house_roof_dressing.gd`, `..._churches.gd`, `..._building_fortification.gd` and
  `map_view_monastic_models.gd` together hold ~110k of GDScript that emits boxes, cylinders and extruded
  outlines. **None of them references a single `res://assets` path.**
- Authored GLB: `tools/burgher_house_kit_common.py` can build a good house, but it ships whole-house
  monoliths - **6 meshes** for 3 tiers - and its own loader comment says that is why a street clones
  one albedo set.

Neither has a part. So a "new building type" costs a whole new mesh or a whole new GDScript builder,
which is why 362 house records are served by 6 meshes plus a tint.

## Deliverable

1. `tools/build_architecture_kit.py`, building on `tools/burgher_house_kit_common.py`, emitting a
   **part library** under `assets/buildings/kit/<family>/<part>.glb`. Every part is authored to the
   AR-01 bay module so parts snap without a gap, has its origin on a documented snap point, and carries
   the AR-03 surface families. Minimum part set, by group:

   - **Ground**: plinth course, exposed undercroft face, cellar hatch, external cellar stair, threshold
     step, kerb return.
   - **Wall bays** per material family (ashlar, rubble, render-over-rubble, limewash, timber frame with
     daub infill, horizontal log, vertical plank, brick): blank bay, door bay, window bay, shuttered-
     counter bay, arched bay, blind-arch bay, putlog-hole variant.
   - **Storey**: storey band / string course, jetty bracket, corbel, floor beam end, hoist beam and
     pulley, tie-rod anchor.
   - **Gable**: triangular gable field, stepped gable, half-hipped end, boarded gable, gable door, gable
     hoist opening, gable vent, crow-stepped coping.
   - **Roof**: roof plane per cover (tile, shingle, thatch, straw) at the AR-01 pitch for that cover,
     ridge, hip, valley, verge, eave with and without gutter, dormer, roof hatch, snow board.
   - **Openings**: door leaves (plank, ironbound, arched), shutters (open, closed, counter), window
     frames (unglazed, shuttered, leaded where AR-01 allows it), grille, loophole.
   - **Attachments**: pentice / lean-to, gallery, outside stair with rail, porch, buttress, chimney and
     smoke hood, flue, signboard bracket, bench, cellar door hood.

2. A **snap and assembly contract** documented in `docs/ARCHITECTURE_KIT.md`: named snap sockets on
   every part, the bay module, allowed rotations, and the rule that a part never bakes in a material -
   it declares a surface family that AR-03 resolves.

3. A **Godot-side part catalogue**, `scripts/map/view3d/architecture_kit_catalogue.gd`, that is an
   explicit registry (never a filesystem walk - `docs/MAP_AUTHORING.md` forbids discovery by walking),
   mapping part id to path, snap sockets, bounds, surface family and LOD set.

4. **LODs** for every part per the ADR 0022 budget, plus a shared-material rule so a street of assembled
   buildings does not create one material per part instance.

5. A **reference assembly** proving the kit: one stone Diele house, one timber-frame house, one log
   dwelling and one craft boda, assembled purely from parts, with a side-by-side against the existing
   monolithic `merchant_stone.glb` / `merchant_timber.glb` / `craft_boda.glb`.

6. `assets/SOURCES.csv` rows for every part and texture; provenance per the ADR 0022 rule.

## Allowed files

- `assets/buildings/kit/**` (new)
- `assets/SOURCES.csv`
- `tools/build_architecture_kit.py` (new)
- `tools/burgher_house_kit_common.py`
- `scripts/map/view3d/architecture_kit_catalogue.gd` (+ `.uid`, new)
- `scripts/map/view3d/architecture_kit_assembler.gd` (+ `.uid`, new)
- `tests/godot/test_architecture_kit.gd` (+ `.uid`, new)
- `tests/python/test_build_architecture_kit.py` (new)
- `tools/capture_ar04_architecture_kit.gd` (+ `.uid`, new)
- `docs/ARCHITECTURE_KIT.md` (new), `docs/ARCHITECTURE.md`, `docs/ASSET_INVENTORY.md`,
  `docs/ART_BIBLE.md`, `docs/reports/ar04_architecture_kit.md`,
  `docs/reports/images/ar04_*.png`, `TODO.md`

## Constraints and non-goals

- Asset freeze P0-040: exactly the files above.
- **No map, blueprint, renderer-wiring or gameplay change.** AR-04 ships the library and the assembler
  plus a reference assembly only. AR-05..AR-12 wire it into real maps. Nothing the player sees changes
  in this task.
- Do not delete or modify the existing procedural builders here. They are retired map by map, from AR-05
  onward, so a regression can always be bisected.
- Do not register kit parts as `MapBlueprint` prefabs. Kit parts are **view-layer output**;
  `docs/MAP_AUTHORING.md` and ADR 0009 keep blueprint prefabs as the gameplay-authoring vocabulary and
  that boundary does not move.
- Every dimension traces to an AR-01 card. No invented storey heights or pitches.
- Parts must be watertight and correctly wound, with no interior faces that will z-fight when two bays
  abut. A part with inverted normals fails the task.
- No part bakes a colour that duplicates AR-03's job.

## Verification

```bash
python3 -m unittest tests.python.test_build_architecture_kit -v
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_architecture_kit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_map_blueprints.gd
python3 tools/validate_asset_sources.py && python3 tools/verify_asset_lint.py && python3 tools/verify_storage_hygiene.py
python3 tools/verify_map_audit.py && python3 tools/verify_map_activation.py
python3 tools/generate_active_docs_report.py --check
```

- `test_architecture_kit.gd` asserts: every catalogue entry loads; every part exposes its declared snap
  sockets; snapped neighbours share a plane within tolerance with no gap and no overlap; no part carries
  a baked material that shadows an AR-03 surface family; every part has its LOD set and is within the
  ADR 0022 triangle budget; the four reference assemblies build from parts only; assembling the same
  building twice from the same inputs gives an identical mesh fingerprint.
- `test_build_architecture_kit.py` asserts the generator is deterministic and the emitted part list
  matches the documented set exactly - a missing part is a failure, not a warning.
- **Zero-change proof for existing maps**: the compiled `MapDefinition` fingerprint and the map-audit
  output are unchanged for all 29 maps. This task must be invisible to the runtime.
- `tools/capture_ar04_architecture_kit.gd` through `tools/godot_render.sh`: a contact sheet of every
  part group under fixed light; the four reference assemblies at the gameplay camera; and the
  side-by-side against the three existing monolithic house GLBs.
- Performance: assembled-vs-monolithic draw call, material and triangle counts recorded in the report
  for the four reference assemblies.
- **Named human visual review** of the four reference assemblies and the side-by-side, explicitly
  answering whether the kit is good enough to build a district from. If the answer is no, the task
  reopens - it does not close on green tests (P0-209b).

## Doc updates

`docs/ARCHITECTURE_KIT.md`, `docs/ARCHITECTURE.md`, `docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`,
`docs/reports/ar04_architecture_kit.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-962 | deps: R-959,R-960 | deliverable: assets/buildings/kit part library built by tools/build_architecture_kit.py covering ground, wall-bay (eight material families), storey, gable, roof (four covers at AR-01 pitches), opening and attachment groups on a documented snap module, an explicit architecture_kit_catalogue.gd registry with sockets/bounds/surface family/LODs, an assembler, docs/ARCHITECTURE_KIT.md snap contract, and four reference assemblies (stone Diele, timber frame, log dwelling, craft boda) built from parts only | allowed files: per docs/tasks/architecture/AR-04_modular_architecture_kit.md | verify: python generator unittest; `--filter=test_architecture_kit`; full Godot suite; blueprint validate; asset sources/lint/storage; map audit and activation; active docs; snapped neighbours gapless and non-overlapping with correct winding; every part within the ADR 0022 triangle budget with its LOD set; deterministic assembly fingerprint; emitted part list matches the documented set exactly; unchanged MapDefinition fingerprint and map audit for all 29 maps proving zero runtime change; part contact sheet, four reference assemblies and side-by-side against the three monolithic house GLBs; draw-call/material/triangle comparison; named human review answering whether the kit can carry a district
```
