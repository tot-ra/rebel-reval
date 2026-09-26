# AR-08: Padise estate building set, 1343 pre-quadrangle phase

Board row: **R-966**. Priority: high. Depends on: AR-04.

## Player-facing goal

Arriving at Padise one week after St George's Night, the player sees a Cistercian working estate on a
plateau above the Kloostri river: a substantial stone hall over an undercroft, a lower stone building
with arched niches projecting south of it, timber conventual and lay ranges, a barn, a mill by the water,
service cottages, a low fieldstone boundary, and the Tallinn-Haapsalu road crossing the river at the ford
that is the reason the house stands here. It is scattered across open ground, not packed into a fortified
square - and after the fire, the damage is on the buildings, not implied by a colour.

## Why this is needed

`world_padise` places **14 house records**, and every one of them is a coloured box with a gable.
`content/maps/world_padise.rrmap` already does the hard historical work in its header: it follows Villu
Kadakas, "Archaeological Studies in Padise Monastery" (AVE 2011, `history/AVE2011_Kadakas_Padise.pdf`),
Fig. 2 and Fig. 3, and it deliberately **excludes** the famous quadrangular claustrum, stone church, gate
towers, gun towers and moat, because Siegburg stoneware from the wall-trench fills dates the northern,
eastern and southern ranges to no earlier than ~1350-1400 and the abbey church was consecrated only in
1448.

But the geometry cannot express any of that. The map's entire architectural vocabulary is nine styles -
`stone.early`, `stone.niche`, `timber.oratory`, `timber.range`, `timber.lay`, `timber.service`,
`timber.barn`, `timber.cottage`, `timber.mill` - differing only by `wall_height` (152 / 112 / 124 / 108 /
96 / 92 / 116 / 84 / 104), `door_side`, `ridge_axis`, and a material keyword. The "two storeys over an
undercroft" the header describes is a number, not a building. The "building with arched niches" that gives
`stone.niche` its name has no niches.

The maintainer named Padise explicitly, and asked for multiple models in one theme rather than one huge
model. Padise in 1343 **is** a scatter of separate buildings, so this is the one site where the historical
truth and the art request are the same thing.

## Deliverable

A set under `assets/buildings/padise/`, kit-bashed on AR-04 with bespoke detail, built to the AR-01
Cistercian card and the Kadakas figures:

1. **The two attested masonry buildings**, as real buildings:
   - `padise_stone_hall` - the substantial building later buried under the western range: limestone
     rubble, two storeys over an undercroft, shingled roof, undercroft entrance, external stair.
   - `padise_niche_building` - the "building with arched niches" projecting south of it, with its arched
     niches actually modelled, since that feature is what names it in the excavation record.
2. **Timber conventual fabric**, each a distinct model, all lower than the stone so the attested masonry
   still dominates the site as the map header requires:
   - `padise_timber_oratory`, `padise_timber_range`, `padise_lay_range`, `padise_service_range`,
     `padise_threshing_barn`, `padise_cottage` (two frontage variants), `padise_watermill` with wheel
     and race.
3. **Site fabric**: `padise_fieldstone_wall` (low boundary, well under a battlement),
   `padise_timber_gate`, `padise_well`, `padise_ford_crossing` and the road apron where the
   Tallinn-Haapsalu road meets the river.
4. **Fire and damage variants.** The map is set about 1 May 1343, one week after the attack and fire.
   Each timber model ships a damaged variant - scorched boards, partly collapsed roof, burnt-out bay -
   and the stone hall ships a smoke-stained variant. The existing rrmap uses `wall.burned` and
   `wall.smoked` styles and `smoked_plaster`; those must resolve to real damage geometry, not a dark tint.
   Which buildings are damaged stays authored in the map, not chosen by the renderer.
5. **Loader wiring** through the AR-04 catalogue, preserving every `primitive=` and building ID in
   `content/maps/world_padise.rrmap` (`stone_hall`, `timber_oratory_1343`, `barn_dwelling_1343` and the
   rest).
6. `assets/SOURCES.csv` rows citing the AR-01 card, `history/AVE2011_Kadakas_Padise.pdf` and the
   `docs/HISTORICAL_AUDIT.md` H21 row, plus `docs/reports/padise_monastery_research_p6_009.md`.

## Allowed files

- `assets/buildings/padise/**` (new), `assets/buildings/kit/**` (Padise-specific parts only)
- `assets/SOURCES.csv`
- `tools/build_padise_buildings.py` (new), `tools/build_architecture_kit.py`
- `scripts/map/view3d/map_view_monastic_models.gd` (+ `.uid`) - Padise path only
- `scripts/map/view3d/map_view_mesh_builder_building_registry.gd` (+ `.uid`)
- `scripts/map/view3d/architecture_kit_catalogue.gd` (+ `.uid`)
- `tests/godot/test_padise_buildings.gd` (+ `.uid`, new)
- `tools/capture_ar08_padise.gd` (+ `.uid`, new)
- `docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`, `docs/CANON.md` (confidence labels only),
  `docs/reports/ar08_padise_estate.md`, `docs/reports/images/ar08_*.png`, `TODO.md`

## Constraints and non-goals

- Asset freeze P0-040: exactly the files above.
- **No `content/maps/world_padise.rrmap` edits.** Every ID, footprint, style, anchor and transition is
  preserved. The map is `active=false` and this task does **not** activate it.
- **The exclusions in the map header are hard requirements, not suggestions.** No quadrangular claustrum,
  no stone abbey church, no gate towers, no gun towers, no moat, no baroque rebuild mass. If the set
  makes Padise look like the Padise on the museum website, the task has failed.
- Every mass is an uncertainty-aware reconstruction. The report must state, per model, whether it is
  `attested` (the two masonry buildings), `plausible composite` (the timber fabric) or `invented`, and
  `docs/CANON.md` gets the labels. Do not present the reconstruction as a measured plan - the map header
  is explicit that it is not.
- Damage variants are authored per building in the existing map data. Do not add a renderer-side damage
  roll, and do not add a damage *system*: phase-damage variants are future content metadata per the
  `docs/HISTORICAL_AUDIT.md` H21 landmark row, not a 1343 baseline mechanic.
- Collision and navigation unchanged; walkability bit-identical. No interiors, no gameplay, no new quest
  or travel hooks.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_padise_buildings,test_monastic_buildings,test_architecture_kit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_map_blueprints.gd
python3 tools/validate_asset_sources.py && python3 tools/verify_asset_lint.py && python3 tools/verify_storage_hygiene.py
python3 tools/verify_map_audit.py && python3 tools/verify_map_activation.py && python3 tools/verify_map_composition.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

- `test_padise_buildings.gd` asserts: every model loads; all 14 house records resolve to an authored
  model; every building, anchor and transition ID in `world_padise.rrmap` still resolves; the stone hall
  is taller than every timber model (the map header's dominance rule, checked numerically); the niche
  building actually carries arched niche geometry; `wall.burned` and `wall.smoked` resolve to damage
  geometry and not only to a darker material; damaged-variant assignment comes from the map data, not
  from a runtime roll; models are within the ADR 0022 budget with LODs; no deleted primitive builder is
  referenced in `scripts/`.
- An **exclusion test**: no model or catalogue entry named or shaped as a claustral quadrangle, abbey
  church, gate tower, gun tower or moat exists in the Padise set. Name the assertion explicitly so a
  future contributor cannot add one silently.
- **Gameplay invariance**: walkable-cell count, largest walkable region and anchor accounting
  bit-identical; the map still reports inactive.
- `git diff --stat content/maps/` is empty.
- `tools/capture_ar08_padise.gd` through `tools/godot_render.sh`: matched before/after plates from the
  road approach, the ford, the stone hall with its undercroft, the niche building's south face, the
  timber ranges, the mill, and one site vista showing the scatter across open ground; a damage plate
  showing scorched timber and the smoke-stained hall; clear noon and midnight; Compatibility and Metal;
  both quality tiers.
- Performance: `world_padise` frame cost, draw calls, materials and triangles, inside budget.
- **Named human visual review** answering: does this read as a working Cistercian estate in 1343 rather
  than the later fortified abbey, and is the fire legible one week on. Green tests do not close this
  (P0-209b).
- **Canon review** of every per-model confidence label against the map header and H21.

## Doc updates

`docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`, `docs/CANON.md`,
`docs/reports/ar08_padise_estate.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-966 | deps: R-962 | deliverable: assets/buildings/padise set for the attested 1343 pre-quadrangle phase per Kadakas AVE 2011 - stone hall with modelled undercroft and external stair, arched-niche building with its niches actually built, timber oratory, conventual range, lay range, service range, threshing barn, two cottage frontages, watermill with wheel and race, fieldstone boundary, timber gate, well, ford crossing and road apron - plus authored fire-damage variants so wall.burned and wall.smoked resolve to damage geometry rather than a dark tint, wired through the AR-04 catalogue | allowed files: per docs/tasks/architecture/AR-08_padise_estate_set.md | verify: `--filter=test_padise_buildings,test_monastic_buildings,test_architecture_kit`; full Godot suite; blueprint validate; asset sources/lint/storage; map audit, activation, composition; active docs; git diff --check; all 14 house records and every building/anchor/transition id in world_padise.rrmap resolve; stone hall numerically taller than every timber model; niche geometry present; damage assignment comes from map data not a runtime roll; an explicit exclusion assertion that no claustral quadrangle, abbey church, gate tower, gun tower or moat exists in the set; models within the ADR 0022 budget with LODs; bit-identical walkability and anchor accounting with the map still inactive; empty `git diff --stat content/maps/`; matched before/after road-approach, ford, stone hall, niche south face, timber range, mill and site-scatter vista plates plus a fire-damage plate at noon and midnight on Compatibility and Metal at both tiers; frame/draw-call/material/triangle budget; named human review that it reads as a 1343 working estate rather than the later fortified abbey and that the fire is legible; canon review of every per-model confidence label
```
