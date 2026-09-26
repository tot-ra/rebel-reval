# AR-12: rural, harbour and coastal building set

Board row: **R-970**. Priority: high. Depends on: AR-04.

## Player-facing goal

Kalamaja, the harbours and the world-travel locations stop looking like the same town with fewer houses.
An Estonian smoke cottage reads as a chimneyless log dwelling with a smoke room and a low eave, a threshing
barn reads as a barn, a boat shed is open to the water with a hull inside, fish sheds carry racks and nets,
and the mills actually have a wheel and sails. A village looks rural, not like a thinned-out Lower Town.

## Why this is needed

The non-urban building population is real but unserved: `world_sacred_grove` 11 house records,
`world_saaremaa` 11, `reval_harbor_north` 10, `reval_harbor_east` (Kalamaja) 8, `viru_gate_foreland` 6,
`world_poide` 5, `world_paide` 5, plus `world_rebel_kings`, `world_parnu`, `world_harju`, `world_sojamae`
and `world_kanavere` at 1-3 each. Around 65 buildings in total.

They are drawn by `scripts/map/view3d/map_view_rural_dwelling_models.gd` (6.0k) and the same box-plus-gable
path, and their primitives are `smoke_cottage_1343` (3 uses), `rural_barn_1343` (5),
`barn_dwelling_1343` (1), `work_shed` (6), `camp` (5) and `coast.boat_shed` as a style. Their entire
vocabulary is `rural.smoke_cottage`, `rural.barn`, `rural.barn_dwelling`, `house.croft`, `house.farm`,
`house.hut`, `camp.shelter`, `camp.work_shed`, `coast.boat_shed` - again separated only by height and a
material keyword.

This also closes a gap the coast pack opened: **CO-02** adds shore debris and **CO-06** adds the vessel
fleet, but nothing adds the shore *buildings* the boats belong to.

## Deliverable

A set under `assets/buildings/rural/`, kit-bashed on AR-04, built to the AR-01 rural and coastal card:

1. **Dwellings** - `smoke_cottage` (two sizes, chimneyless with a smoke hood and low eave),
   `barn_dwelling` (the Estonian `rehielamu` type: threshing floor and living end under one roof),
   `croft_cottage`, `log_hut`, `plank_dwelling`.
2. **Farm fabric** - `threshing_barn`, `hay_barn`, `byre`, `granary_on_stones`, `drying_kiln`,
   `root_cellar_mound`, `yard_fence_run`, `field_gate`.
3. **Coastal and harbour** - `boat_shed_open` (open to the water, sized to take a CO-06 fishing hull),
   `net_store`, `fish_drying_shed`, `smokehouse`, `salt_store`, `harbour_crane_timber`,
   `quay_warehouse`, `landing_stage_hut`.
4. **Mills** - `watermill` with wheel, race and sluice; `windmill_post` with sails. The maps already author
   `timber.mill`; a mill without a wheel or sails is the clearest possible tell that a building is a box.
5. **Camp and temporary** - `camp_shelter` (two variants), `work_shed` (two variants),
   `supply_lean_to`, `field_forge_shelter`, matching the existing `camp` and `work_shed` primitives
   one-for-one.
6. **Regional variation.** Saaremaa, Pärnu and the Harju inland sites do not use the same dwelling as
   Kalamaja. At minimum: a coastal variant with tar and reed, and an inland variant with straw and heavier
   logs, per the AR-01 card. `world_saaremaa` in particular is a campaign wrapper whose card allows only
   "timber camp shelters and a supply shed" - respect that.
7. Loader wiring through the AR-04 catalogue; every `primitive=` and ID in the twelve affected rrmap
   sources preserved.
8. `assets/SOURCES.csv` rows citing the AR-01 card and `docs/FLORA_FAUNA.md` where a building carries
   plant or animal fabric (thatch species, drying racks).

## Allowed files

- `assets/buildings/rural/**` (new), `assets/buildings/kit/**` (rural parts only)
- `assets/SOURCES.csv`
- `tools/build_rural_buildings.py` (new), `tools/build_architecture_kit.py`
- `scripts/map/view3d/map_view_rural_dwelling_models.gd` (+ `.uid`)
- `scripts/map/view3d/map_view_fish_drying_rack_models.gd` (+ `.uid`) - snap alignment only
- `scripts/map/view3d/map_view_mesh_builder_building_registry.gd` (+ `.uid`)
- `scripts/map/view3d/architecture_kit_catalogue.gd` (+ `.uid`)
- `tests/godot/test_rural_buildings.gd` (+ `.uid`, new)
- `tools/capture_ar12_rural_harbour.gd` (+ `.uid`, new)
- `docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`, `docs/CANON.md` (confidence labels only),
  `docs/reports/ar12_rural_harbour.md`, `docs/reports/images/ar12_*.png`, `TODO.md`

## Constraints and non-goals

- Asset freeze P0-040: exactly the files above.
- **No rrmap edits** for any of the twelve maps. `reval_harbor_east` is a live coast-pack target, so a
  cell change here would collide with CO-03 and CO-04.
- **Coordinate with the coast pack.** CO-02 owns shore debris props, CO-06 owns vessels, CO-03/CO-04 own
  the shore silhouette and elevation. AR-12 owns **buildings only**. The `boat_shed_open` opening must be
  sized against the CO-05 dossier hull dimensions so a CO-06 hull fits; if CO-05 has not landed, size it
  from the current `map_view_fishing_boat_builder.gd` extents and note the dependency in the report.
- Collision and navigation unchanged; walkability bit-identical.
- Respect each map's `docs/HISTORICAL_AUDIT.md` card. `world.saaremaa` gets camp fabric and a supply shed,
  not a village. Do not add built mass to make a wrapper map look fuller.
- Mills are props, not mechanisms: the wheel and sails may be static or driven by existing wind state if
  that is free, but no milling gameplay, no new simulation.
- No interiors, no enterable sheds.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_rural_buildings,test_architecture_kit,test_fishing_net
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_map_blueprints.gd
python3 tools/validate_asset_sources.py && python3 tools/verify_asset_lint.py && python3 tools/verify_storage_hygiene.py
python3 tools/verify_map_audit.py && python3 tools/verify_map_activation.py && python3 tools/verify_map_composition.py
python3 tools/verify_building_variety.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

- `test_rural_buildings.gd` asserts: every model loads; all ~65 rural, harbour and world house records
  resolve; every `primitive=` (`smoke_cottage_1343`, `rural_barn_1343`, `barn_dwelling_1343`, `work_shed`,
  `camp`) maps one-for-one to an authored model with its ID intact; the smoke cottage has no chimney and
  does have a smoke hood; the barn dwelling has both a threshing floor bay and a living end; the watermill
  has a wheel, race and sluice and the windmill has sails; the boat shed opening is wide and tall enough
  for the fishing-hull extents; `world_saaremaa` resolves only to camp shelters and a supply shed, with a
  named assertion that no village dwelling is placed there; coastal and inland dwelling variants are
  distinct models; models within the ADR 0022 budget with LODs.
- **Gameplay invariance**: per-map walkable cells, largest walkable region and anchor accounting
  bit-identical across all twelve maps; activation status unchanged.
- `git diff --stat content/maps/` is empty. Confirm no overlap with in-flight coast-pack files.
- `tools/capture_ar12_rural_harbour.gd` through `tools/godot_render.sh`: matched before/after plates of the
  Kalamaja shore frontage, a boat shed with a hull inside, the fish-drying yard, a smoke cottage, a barn
  dwelling, the watermill, the windmill, a Saaremaa camp, and one plate comparing a coastal dwelling beside
  an inland one; clear noon, overcast and midnight; Compatibility and Metal; both quality tiers.
- Performance: `reval_harbor_east` and `world_sacred_grove` frame cost, draw calls, materials and
  triangles, inside budget.
- **Named human visual review** answering: does Kalamaja read as a fishing suburb rather than a thin Lower
  Town, and is the smoke cottage recognisably Estonian. Green tests do not close this (P0-209b).

## Doc updates

`docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`, `docs/CANON.md`,
`docs/reports/ar12_rural_harbour.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-970 | deps: R-962 | deliverable: assets/buildings/rural set covering chimneyless smoke cottages in two sizes, the rehielamu barn dwelling, croft cottage, log hut and plank dwelling; threshing barn, hay barn, byre, granary on stones, drying kiln, root-cellar mound and yard fencing; open boat shed sized to a CO-05/CO-06 fishing hull, net store, fish-drying shed, smokehouse, salt store, timber harbour crane, quay warehouse and landing-stage hut; watermill with wheel, race and sluice and a post windmill with sails; camp shelters, work sheds and supply lean-tos matching the existing camp and work_shed primitives; plus distinct coastal and inland dwelling variants | allowed files: per docs/tasks/architecture/AR-12_rural_harbour_set.md | verify: `--filter=test_rural_buildings,test_architecture_kit,test_fishing_net`; full Godot suite; blueprint validate; asset sources/lint/storage; map audit, activation, composition; building variety; active docs; git diff --check; all ~65 rural/harbour/world house records and every primitive resolve one-for-one with ids intact; smoke cottage chimneyless with a smoke hood; barn dwelling has both threshing bay and living end; watermill has wheel/race/sluice and windmill has sails; boat shed opening fits the fishing-hull extents; named assertion that world_saaremaa resolves only to camp shelters and a supply shed; coastal and inland variants are distinct models; models within the ADR 0022 budget with LODs; bit-identical walkability across all twelve maps; empty `git diff --stat content/maps/` and no overlap with in-flight coast-pack files; matched before/after Kalamaja shore, boat shed with hull, drying yard, smoke cottage, barn dwelling, watermill, windmill, Saaremaa camp and coastal-vs-inland plates at noon/overcast/midnight on Compatibility and Metal at both tiers; frame/draw-call/material/triangle budget; named human review that Kalamaja reads as a fishing suburb and the smoke cottage as Estonian
```
