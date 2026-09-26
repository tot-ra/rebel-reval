# AR-07: Monastery District bespoke building set

Board row: **R-965**. Priority: high. Depends on: AR-04.

## Player-facing goal

Standing in the Monastery District, the player reads a religious precinct: St Michael's Cistercian
convent is an enclosed group of related stone and timber buildings around a cloister walk, with a
gated wall, a chapel that is clearly a chapel, a service wing that is clearly service, and garden and
work ground between them. St Olaf's is a compact parish church with a massive west tower, in its 1343
fabric. None of it is a block. The district stops being indistinguishable from the merchant quarters
next to it.

## Why this is needed

`monastery_quarter` places **29 house records**. Its landmarks are drawn by
`scripts/map/view3d/map_view_monastic_models.gd` (18k) and
`scripts/map/view3d/map_view_mesh_builder_churches.gd` (11k), and both contain **zero `res://assets`
references**. `st_michaels_precinct_1343`, `st_michaels_chapel_1343`, `st_michaels_service_wing_1343`,
`timber_oratory_1343`, `stone_church`, `monastic_range` and `st_olaf_silhouette` are all assembled from
`Primitives`-level boxes and extruded outlines at runtime. `add_cloister_walk`, `add_oratory_facade` and
`_add_precinct_portal` are the entire architectural detail budget for a convent.

The map's own authored styles confirm the limitation: `house.convent.precinct`, `house.convent.chapel`,
`house.convent.service` and `house.convent` differ only in `wall_height` (128 / 112 / 88 / 128),
`door_side`, `ridge_axis`, and a limestone-or-plaster keyword.

The maintainer named this district explicitly, and asked for **multiple models in one theme rather than
one huge model**. That is what a Cistercian claustral group actually is, so the request and the history
agree.

## Deliverable

A bespoke, thematically coherent set under `assets/buildings/monastic/`, kit-bashed on the AR-04 part
library with bespoke ornament, built to the AR-01 Cistercian and parish-church cards:

1. **St Michael's convent group** - separate models, shared vocabulary, all snapping to the same
   precinct grid:
   - `convent_church_east` - the church or oratory, 1343 fabric only
   - `convent_range_dorter` - claustral range with dorter over undercroft
   - `convent_range_refectory` - refectory range with reader's pulpit niche
   - `convent_chapter_house`
   - `convent_cloister_walk` - a repeatable bay so the walk is built, not stretched
   - `convent_service_wing` - kitchen, brewhouse, bakehouse end
   - `convent_precinct_wall` + `convent_precinct_gate` - the gated boundary
   - `convent_well_house`, `convent_dovecote`, `convent_garden_frame` - the small fabric that makes a
     precinct read as inhabited
2. **St Olaf 1343** - `st_olaf_church_1343` plus `st_olaf_west_tower_1343` and
   `st_olaf_churchyard_wall`: compact older church, massive west tower, completed 1330-era vault work.
   The 15th-century chancel, basilica plan and giant spire are **excluded**, per the
   `docs/HISTORICAL_AUDIT.md` `monastery_quarter` landmark row.
3. **Guild frontage stays generic.** `great_guild_front`, `blackheads_corner` and `brotherhood_wing`
   keep their stable IDs and continue to render as generic merchant masses, exactly as the
   `content/maps/monastery_quarter.rrmap` header comment (**P4-023e**) already records. They are AR-05 /
   AR-10 work, not monumental guild halls here.
4. **Loader replacement.** `map_view_monastic_models.gd` and the St Olaf path in
   `map_view_mesh_builder_churches.gd` load the authored set through the AR-04 catalogue. The primitive
   assembly code for the replaced landmarks is deleted; every `primitive=` and building ID in
   `content/maps/monastery_quarter.rrmap` is preserved.
5. **Interior-facing nothing.** Exteriors and the cloister walk only. `nunnatorn_interior` and
   `kuldjala_interior` are separate prototypes and are out of scope.
6. `assets/SOURCES.csv` rows for every mesh and texture, with the AR-01 card and the
   `docs/HISTORICAL_AUDIT.md` evidence row (H03-H05, H14) in `edits`.

## Allowed files

- `assets/buildings/monastic/**` (new), `assets/buildings/kit/**` (monastic parts only)
- `assets/SOURCES.csv`
- `tools/build_monastic_buildings.py` (new), `tools/build_architecture_kit.py`
- `scripts/map/view3d/map_view_monastic_models.gd` (+ `.uid`)
- `scripts/map/view3d/map_view_mesh_builder_churches.gd` (+ `.uid`)
- `scripts/map/view3d/map_view_mesh_builder_building_registry.gd` (+ `.uid`)
- `scripts/map/view3d/architecture_kit_catalogue.gd` (+ `.uid`)
- `tests/godot/test_monastic_buildings.gd` (+ `.uid`, new)
- `tools/capture_ar07_monastery_district.gd` (+ `.uid`, new)
- `docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`, `docs/CANON.md` (confidence labels only),
  `docs/reports/ar07_monastery_district.md`, `docs/reports/images/ar07_*.png`, `TODO.md`

## Constraints and non-goals

- Asset freeze P0-040: exactly the files above.
- **No `content/maps/monastery_quarter.rrmap` edits.** Every building ID, `primitive=`, anchor, patrol,
  transition, spawn and landmark ID is preserved unchanged. `monastery_quarter` is `active=false`; this
  task does **not** activate it - activation has its own gates (`tools/verify_map_activation.py`).
- Collision and navigation footprints are unchanged; walkability bit-identical.
- Historical exclusions are hard: no 15th-century St Olaf chancel, basilica or giant spire; no Great
  Guild Hall (1407-10); no Brotherhood or Blackheads institutional frontage. The
  `docs/HISTORICAL_AUDIT.md` cross-map exclusion 2 stands.
- St Michael's exact 1343 above-ground mass is labelled **U** (uncertain) in the audit. The set must be an
  uncertainty-aware reconstruction: state in the report which masses are `attested`, which are
  `plausible composite`, and keep the timber-vs-stone balance the audit implies. Do not present the
  reconstruction as measured.
- The precinct interior stays substantially open per the audit's density target (built 35-50%). Do not
  fill it with generic houses to make it look busy.
- No new gameplay, no enterable interiors, no quest hooks, no NPC changes.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_monastic_buildings,test_architecture_kit,test_churches
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_map_blueprints.gd
python3 tools/validate_asset_sources.py && python3 tools/verify_asset_lint.py && python3 tools/verify_storage_hygiene.py
python3 tools/verify_map_audit.py && python3 tools/verify_map_activation.py && python3 tools/verify_map_composition.py
python3 tools/verify_building_variety.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

- `test_monastic_buildings.gd` asserts: every model in the set loads and snaps to the precinct grid; every
  replaced `primitive=` id in `monastery_quarter.rrmap` resolves to an authored model; every building,
  anchor, patrol and landmark ID in that map still resolves; the cloister walk is built from repeated bays
  rather than a scaled single mesh; `great_guild_front`, `blackheads_corner` and `brotherhood_wing` do
  **not** resolve to monumental institutional geometry; no deleted primitive builder is referenced
  anywhere in `scripts/`; every model is within the ADR 0022 triangle budget with its LODs.
- **Gameplay invariance**: `monastery_quarter` walkable-cell count, largest walkable region and map-audit
  anchor accounting bit-identical; `verify_map_activation.py` still reports the map as inactive.
- `git diff --stat content/maps/` is empty.
- `tools/capture_ar07_monastery_district.gd` through `tools/godot_render.sh`: matched before/after plates
  of the precinct from the gate approach, the cloister walk, the chapel front, the service court, and
  St Olaf from the Pikk approach; one district vista showing the precinct against the merchant frontage
  to prove the two read differently; clear noon, overcast and midnight; Compatibility and Metal; both
  quality tiers.
- Performance: `monastery_quarter` frame cost, draw calls, materials and triangles, inside budget.
- **Named human visual review** answering two questions explicitly: does this read as a Cistercian
  precinct, and is St Olaf recognisable as its 1343 self rather than the modern church. Green tests do not
  close this (P0-209b).
- **Canon review** of the confidence labels for every reconstructed mass.

## Doc updates

`docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`, `docs/CANON.md`,
`docs/reports/ar07_monastery_district.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-965 | deps: R-962 | deliverable: bespoke assets/buildings/monastic set for the Monastery District as multiple models in one theme - St Michael's convent church/oratory, dorter range, refectory range, chapter house, repeatable cloister-walk bay, service wing, precinct wall and gate, well house, dovecote, garden frame - plus St Olaf 1343 church, west tower and churchyard wall, with map_view_monastic_models.gd and the St Olaf path in map_view_mesh_builder_churches.gd switched to the AR-04 catalogue and their primitive assembly deleted | allowed files: per docs/tasks/architecture/AR-07_monastery_district_set.md | verify: `--filter=test_monastic_buildings,test_architecture_kit,test_churches`; full Godot suite; blueprint validate; asset sources/lint/storage; map audit, activation, composition; building variety; active docs; git diff --check; every replaced primitive id and every building/anchor/patrol/landmark id in monastery_quarter.rrmap still resolves; cloister walk built from repeated bays; great_guild_front, blackheads_corner and brotherhood_wing stay generic merchant masses per P4-023e; no 15th-century St Olaf chancel, basilica or spire and no Great Guild/Blackheads frontage; models within the ADR 0022 budget with LODs; bit-identical walkability and anchor accounting with the map still inactive; empty `git diff --stat content/maps/`; matched before/after gate-approach, cloister, chapel, service-court and St Olaf plates plus a precinct-vs-merchant district vista at noon/overcast/midnight on Compatibility and Metal at both tiers; frame/draw-call/material/triangle budget; named human review that it reads as a Cistercian precinct and that St Olaf is its 1343 self; canon review of the confidence label on every reconstructed mass
```
