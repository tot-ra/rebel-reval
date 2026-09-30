# UF-13: Dominican St Catherine's and Cistercian St Michael's precincts

> **Cancelled, 2026-09-30 - fully duplicated.** St Catherine's is owned by LM-02 (**R-1124**) and
> St Michael's by LM-05 (**R-1130**) in the Historical landmark remodel pack (epic **R-1121**), both
> naming the same building ids on the same maps. Both landmarks are already placed, so no placement
> task remains. This document is retained only for the verified repository state it recorded.
> One requirement must not be lost: the convent closes stay open ground registered as owned
> `open_regions`, and no signed historical band may be lowered for a model - carried into UF-09
> (**R-1118**) and to be restated in LM-02 and LM-05. See [pack README](README.md#ownership-seam).

Board row: **R-1125**. Priority: high. Depends on: **R-1118**, **R-1115**, **R-1114**, **R-960**. Consume **R-965** (AR-07) if its approved set lands first. Serialize active Lower Town work with **R-986** (WB-14) and **R-964** (AR-05).

## Player-facing goal

Walk past two religious houses and recognise two enclosed precincts, not more domestic blocks: a long Dominican church and preaching close on the active Lower Town map, and a Cistercian nunnery with church, ranges, garden and controlled gate in the monastery belt. The open ground is part of their identity, not space waiting for houses. Owner: Map for precincts, Art for the named exteriors, Dev for existing loader bindings; independent QA accepts the routes and open-space accounting. Slice: urban-form-landmarks.

## Why this is needed

Checked on 2026-09-30. content/maps/lower_town_slice.rrmap places `st_catherines_church` at **35,3**, footprint **21 x 10 cells**, using `house.south.h192.05`, an ordinary generated house style. It also has `monastery_cloister` (**18 x 12**) and `monastery_barn` (**8 x 6**), `katariina_kaik` at **59,22** and `monastery_gate` at **47,16**. These are existing IDs on the active map, not permission to move the institution to monastery_quarter.

There is an important correction to the correction: St Catherine's is **not only an ordinary recoloured box at runtime**. scripts/map/view3d/map_view_mesh_builder_building_registry.gd gives its ID exceptional church priority. scripts/map/view3d/map_view_mesh_builder_buildings.gd dispatches that ID to `build_st_catherines_church`; scripts/map/view3d/map_view_mesh_builder_churches.gd adds a nave roof, lancets, buttresses, west bell tower and east gable cross. The authored style is wrong for the named landmark, but the runtime church route already exists. The work is to reconcile the style and upgrade that route, not add another church renderer.

content/maps/monastery_quarter.rrmap has **159 house records**, not AR-07's old **29**. St Michael's already occupies **three** buildings: `st_michaels_convent` (**22 x 14**), `convent_chapel` (**14 x 10**) and `convent_service_wing` (**10 x 22**). Their three dedicated primitives are `st_michaels_precinct_1343`, `st_michaels_chapel_1343` and `st_michaels_service_wing_1343`, all known to the registry and built by scripts/map/view3d/map_view_monastic_models.gd. Three named precinct-wall runs and `sign.convent` already exist. None of these is in south_quarter.

Open-space ownership is incomplete rather than absent. docs/data/monastery_quarter_authoring_contract.json currently has **one** `open_regions` entry, `outer_wall_verge_and_road`. docs/data/lower_town_authoring_contract.json has **three** route reserves, not an explicitly owned Dominican close. tools/verify_map_composition.py enforces the Lower Town ownership path and `exclude_from_unowned_empty_region`; tools/audit_map_composition.gd loads the named JSON or the map-name fallback. scripts/map/map_composition_audit.gd consumes `bounds_cells` rectangles. The exclusion affects the **unowned-empty-region metric**, not built-density percentages or actual walkability. Calling the whole district a close would conceal a placement failure.

## Deliverable

1. **Dominican St Catherine's, `landmark.st_catherines_dominican`.** Current state: generic authored house style **and** an ID-specific procedural church renderer on **lower_town_slice**. Route choice: **replace that existing church builder with an authored ADR 0025 B exterior**, consuming an approved AR-07 equivalent if the AR owner has actually delivered this named church. AR-07's current task centres on St Michael and St Olaf; it must not be assumed to contain St Catherine simply because it is called a monastery set. Reuse approved secondary kit parts without creating another monastic kit. Remove or redirect the old procedural geometry for this ID, never leave it behind the new GLB. Correct the authored institutional style through known `house.church` / `stone_church` routing, not an invented primitive.

   **1343 phase:** history/dossiers/religion/churches-and-religious-houses.md records the **1246** refoundation, stone church/east range from the **1260s** and largely usable fabric around **1300** as `attested`. The April arrangement of close, garden, service work and precise church mass is `plausible composite`. Target a long limestone hall, restrained portal, associated range and legible street gate around open precinct ground. Do not assume every feature in the current renderer, especially its west bell tower, is approved evidence. **First step: a Canon Keeper-signed evidence sub-task resolves the 1343 bell treatment and any unestablished range/portal dimensions before model production.**

   **Exclusions:** no final **eight-bay** late-medieval hall, no unqualified transfer of the peak **67.7 x 18.5 m** footprint, no late-14th/early-15th-century enlargement or later Gothic ornament, no Blackheads patronage and no post-Reformation appearance. Church and primary stone/claustral masses are **B** under the budget below. LOD2 keeps the approved long hall, range roofs and gate profile. Collision comes from authored 2D church/wall footprints; the GLB never creates blocking cells. Preserve `st_catherines_church`, `monastery_cloister`, `monastery_barn`, `katariina_kaik`, `monastery_gate` and every unrelated active-map ID. Bind the exact dedicated UF-09 `anchor_id` on lower_town_slice; the nearby `katariina_kaik` anchor does **not** satisfy a dedicated church anchor by proximity.

2. **Cistercian St Michael's, `landmark.st_michaels_cistercian`.** Current state: a three-building procedural precinct on **monastery_quarter**, already using three recognised primitives. Route choice: **consume AR-07's approved church, claustral and service set**, replacing geometry inside map_view_monastic_models.gd while retaining its public boundary. If it is not yet delivered, only an explicit AR-07 owner handoff may delegate the named primary masses here; do not build the same set under two directories. There is no South Quarter placement alternative.

   **1343 phase:** the church dossier and history/dossiers/religion/ecclesiastical-precinct-boundaries-1343.md support the **1249** foundation and **1340s** wall-incorporation programme as `attested`; the precise garden area and April construction extent remain `plausible composite`. The dossier explicitly leaves the close's hectares unknown. Target an enclosed garden/work court, chapel and related stone ranges, subordinate timber service wing, controlled gate and evidence-backed unfinished wall tie-in. Keep that western/northern monastery-belt identity distinct from the eastern Dominican friary. Any unsupported range elevation, close boundary or construction extent first becomes a Canon Keeper-signed evidence sub-task.

   **Exclusions:** no completed later convent enlargement, no post-**1433** rebuild, no **1355 Nuns' Gate** name presented as attested for April 1343, no later tourist basilica, no filled or roofed-over garden. The church and primary stone/claustral ranges are **B**; subordinate timber service ranges may be **K-L** with AR-07 presets. LOD2 retains church/range roofs and the gate while preserving the open centre. Collision remains footprint-authored. Preserve `st_michaels_convent`, `convent_chapel`, `convent_service_wing`, `convent_precinct_wall_north`, `convent_precinct_wall_west`, `convent_precinct_wall_south`, `sign.convent`, `monastery_close` and all three existing primitive names. Bind the exact UF-09 anchor at the precinct entrance, not a copied tourist-catalog South Quarter anchor.

3. **Budget, quoted from ADR 0025 Decision 3.** B models: **60,000 / 18,000 / 4,000 triangles** at LOD0/1/2; switches **60 / 140 world units**; never culled inside their map; at most **8 material slots** and one **2048 x 2048** trim atlas per B model. K-L subordinate service buildings: **14,000 / 4,500 / 900 triangles**, switches **40 / 90**, camera-far culling, **6 shared material slots** and no embedded images in K parts. A resident B theme shares **180,000 LOD0 triangles** and **12 MiB**, including consumed AR-07 assets; it is not a new allowance per UF site. Any building GLB is at most **6 MiB**, a texture **4 MiB**, tileable surfaces **1024 x 1024**, each resident map **64 building materials**, and assets/buildings as a whole **96 MiB**. Three authored LOD meshes use visibility ranges with **3.0-unit margin**, fade disabled and minimum-tier distances multiplied by **0.6**. Import-generated LOD alone does not qualify. Group assets must expose named pieces for existing footprint bindings rather than one giant closed box over the court.
4. **Owned open regions and real gates.** Append narrowly bounded close entries to the **existing** lower_town_authoring_contract.json and monastery_quarter_authoring_contract.json. Each has a stable `id`, measured `bounds_cells: [x, y, width, height]`, a reason linking the precinct evidence and `exclude_from_unowned_empty_region: true`. Use multiple rectangles if needed; exclude only actual open-ground cells, not churches, gate approaches or unrelated frontage. Preserve existing entries. Make the monastery threshold card name its actual JSON ownership path so the audit loads the same source explicitly. Do not put `open_regions` directly into the threshold card and assume they are consumed.

   The close remains unroofed ground with a continuous precinct boundary except authored gate openings. Measure boundary continuity and prove a route from street to gate to close without opening unplanned gaps. Render-only replacement retains walkability bit-for-bit. If Map must add a missing precinct wall or gate, record the exact cell delta and independent route approval first; the active Lower Town parity fixture may be amended only for those named, deliberate source changes. Unrelated demo, patrol and door cells stay identical. A band failure is a blocker, not a reason to fill the court or redraw its ownership mask.
5. **Register and acceptance.** Use UF-09's exact fields, site IDs and `absent` / `anchored` / `modelled` statuses. `modelled` requires an approved existing GLB `asset_path` and exact registered anchor on the correct map; remove only the corresponding absence grace. Preserve `existing_geometry_ids`, `phase_1343`, `later_phase_excluded`, `model_tier`, `confidence`, `evidence_class`, `source_ids`, `street_id` and `address_note`. The overall reconstruction label is `plausible composite` unless Canon approves stronger evidence; A/B/C/D/U evidence classes are not confidence labels. Keep the generic-style/procedural-route distinction in the linked report until UF-09's strict schema has an approved implementation-state field.

## Allowed files

Exact paths for later implementation only. Approved AR assets are consumed in place and not copied to fallback paths. This rewrite changes only this contract.

- assets/buildings/landmarks/st_catherines/st_catherines_1343.glb
- assets/buildings/landmarks/st_catherines/st_catherines_1343.glb.import
- assets/buildings/landmarks/st_michaels/st_michaels_1343.glb
- assets/buildings/landmarks/st_michaels/st_michaels_1343.glb.import
- generated/blender/reval_convents_v1/reval_convents_1343.blend
- tools/generate_reval_convents.py
- scripts/map/view3d/map_view_mesh_builder_building_registry.gd
- scripts/map/view3d/map_view_mesh_builder_buildings.gd
- scripts/map/view3d/map_view_mesh_builder_churches.gd
- scripts/map/view3d/map_view_monastic_models.gd
- content/maps/lower_town_slice.rrmap
- content/maps/monastery_quarter.rrmap
- tests/fixtures/maps/lower_town_slice.parity.json
- docs/data/lower_town_authoring_contract.json
- docs/data/monastery_quarter_authoring_contract.json
- docs/data/map_composition_thresholds.json
- content/world/reval_outdoor_layout.json
- tests/godot/test_reval_convents.gd
- tests/godot/test_reval_convents.gd.uid
- tools/capture_uf13_convents.gd
- tools/capture_uf13_convents.gd.uid
- docs/data/reval_landmark_register_1343.json
- docs/reports/reval_landmark_placement_1343.md
- docs/reports/uf13_convents.md
- assets/SOURCES.csv
- docs/HISTORICAL_AUDIT.md

## Constraints and non-goals

- **R-1114 must land first**, explicitly, because St Catherine touches the active lower_town_slice. R-1115 supplies monastery streets. No concurrent writes with WB-14/R-986 or AR-05/R-964; Producer must record the ordered path handoff before claiming work. Likewise serialize monastery and shared renderer changes with R-285, AR-07 and UF-11. A common file such as provenance, register or layout is also a write conflict, not an exception.
- ADR 0025 remains **Proposed, awaiting maintainer acceptance**. R-960 must clear that decision gate before any asset or landmark code lands. P0-040 authorises only listed files. Use shared surfaces, in-house deterministic generators and one assets/SOURCES.csv row per new asset/source file with rights and checksum. Extra GLBs, textures, source files or catalogue edits require an exact-path amendment. No image-to-3D primary mass or imported external ornament here.
- No South Quarter map or ownership edits: St Michael is not there. Keep South Quarter's **40-55% inside-wall** and **10-25% outside-wall** density bands and its enforced state unchanged. Keep Lower Town's **45-60%** built-density band, **1200-cell** empty-region cap, `enforce=true`, `enforcement_state=enforced` and H04-H05/H09-H10 references. Do not lower any signed historical band, increase a cap, widen a mask, flip enforcement or introduce blanket grace to hide a red audit.
- Keep all stable IDs and existing activation states. No new enterable interior, quest, convent economy, city-wall redesign or ordinary-house density pass. No late-Gothic Niguliste nave, post-1402 Town Hall, 15th/16th-century Oleviste spire, baroque Toompea palace wing or Fat Margaret may be introduced as background decoration.
- No second renderer and no new primitive name. A new `view_landmark` kind would require a separate exact-path amendment for scripts/map/map_definition.gd (`VIEW_LANDMARK_KINDS`), scripts/map/map_blueprint_compiler_build.gd (`_compile_landmark` field copy) and scripts/map/map_blueprint_compiler.gd (`LANDMARK_OVERRIDE_KEYS`), with round-trip tests. This row uses existing building routes instead.
- Rebuild content/world/reval_outdoor_layout.json in the same commit as every outdoor `.rrmap` change. Model geometry never edits terrain relief to fit its base.

## Verification

Run from the repository root after implementation. The asset-governance scripts exist; the new focused test and capture tool belong to this row, and R-1118 supplies the register gate.

```bash
git diff --stat -- content/maps/
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_reval_convents,test_lower_town_authoring_contract,test_monastery_quarter_prototype_map
godot --headless --path . --script tools/validate_map_blueprints.gd
godot --headless --path . --script tools/run_godot_tests.gd
godot --headless --path . --script tools/build_world_layout.gd
godot --headless --path . --script tools/build_world_layout.gd -- --check
python3 tools/verify_world_layout.py
python3 tools/verify_landmark_register.py
python3 tools/verify_map_composition.py
python3 tools/validate_asset_sources.py
python3 tools/verify_asset_lint.py
python3 tools/verify_runtime_glb_budget.py
python3 tools/verify_storage_hygiene.py
python3 tools/verify_map_audit.py
python3 tools/verify_map_activation.py
python3 tools/verify_map_conversion_plan.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

Before claiming, the map diff must be clean of another worker's changes. After delivery, it contains only the named precinct changes. `test_reval_convents` checks both register-to-anchor-to-GLB chains, correct maps, three LODs, budgets, known primitives and one render path per building. It asserts St Catherine is no longer authored as `house.south.h192.05` without duplicating its existing church route. It preserves all three St Michael IDs and tests a continuous wall boundary with passable gates, close ownership rectangles that do not mask built fabric, and no roofs or house footprints covering the open centre. Negative fixtures cover a filled close, wrong owning map, missing gate, missing ownership reference and a duplicate renderer.

Snapshot the complete South Quarter threshold card and compare it unchanged after the edit, along with every signed band and enforcement value for touched maps. Compare open-region accounting with and without the new entries: unowned-empty cells change only by the valid close cells, while built-density denominator and physical walkability do not change because of the metadata. The ownership paths loaded by the audit must be the two named JSONs. Test every route and patrol and independently replay New Game to the forge, Mart and the anvil pickup; active-map safety is not established by a church screenshot.

Capture matched before/after plates **outside each gate, inside each close, along each street frontage and across each precinct against ordinary fabric**, plus 6/12-unit third-person views and maximum orthographic zoom. The new capture tool implements the plate names and arguments below, a ten-second `lod_dolly` frame sequence through both switches, and a non-rendering `--verify-distinct` mode. Record camera transforms in docs/reports/uf13_convents.md.

```bash
for plate in dominican_gate dominican_close dominican_street dominican_vista cistercian_gate cistercian_close cistercian_street cistercian_vista near6 near12 far lod_dolly; do
  for condition in noon overcast dusk midnight; do
    tools/godot_render.sh --rendering-method gl_compatibility --script tools/capture_uf13_convents.gd -- --phase after --plate "$plate" --condition "$condition" --tier recommended --output "/tmp/uf13_after_${plate}_${condition}_gl_recommended.png"
  done
done
godot --headless --path . --script tools/capture_uf13_convents.gd -- --verify-distinct /tmp/uf13_after
```

Repeat on the pre-change revision with `before` in phase and filenames, at minimum tier, and on Metal using `--rendering-method mobile --rendering-driver metal` with distinct output suffixes on a supported host. Use only tools/godot_render.sh for GPU capture, never a visible Godot window. Run one process per plate for day/night calibration. Validate nonempty files, hashes and pixel differences before reviewing them; identical noon/night plates fail. Noon is clear, overcast includes rain, midnight is moonlit with torches. Use 1280 x 720 images and the ADR 1.5 MiB active-plate soft cap; raw captures remain outside the repo with durable evidence links and hashes in the report.

Canon Keeper signs both 1343 phases, dimensions and exclusions. A maintainer-named human Art reviewer records accept/amend/reject, name and ISO date against the seven ADR 0025 checks, and explicitly judges whether each close reads as intentional religious ground rather than an empty or roofed block. Independent QA signs active-demo replay, route continuity, band invariance and capture integrity. Record frame p95 regression **<= 10%**, building draw calls **<= 450/300**, submitted triangles **<= 2.0M/0.8M**, and assembly **<= 4 ms** for recommended/minimum. R-653 still gates acceptance on the actual minimum device.

## Doc updates

Update the two UF-09 entries, linked placement report, both existing authoring contracts, monastery ownership-path reference, row evidence report and assets/SOURCES.csv. List exact close rectangles, evidence, unchanged bands and any independently approved collision/parity delta. Canon Keeper owns historical-audit approval. Producer records the UF-05 dependency and exclusive WB-14/AR-05 path handoff on R-1125. No TODO.md, South Quarter file or pack README edit belongs to this rewrite; do not copy the corrupted draft's wrong map ownership into a new contract.

## TODO.md line

- [ ] R-1125 | deps: R-1118, R-1115, R-1114, R-960; consume R-965 by approved handoff; serialize R-986/R-964 | deliverable: upgrade existing St Catherine and St Michael render routes on Lower Town and monastery maps, with registered anchors, B/K-L phase-correct models, passable precinct gates and owned open-region closes | verify: test_reval_convents; full map/world/asset/composition gates; unchanged signed bands; active-demo replay; distinct GPU plates; Canon, named human Art and independent QA acceptance
