# UF-12: Toompea castle and the Dome Church on the compiled hill

> **Scope narrowed, 2026-09-30.** The Small Castle moved to LM-04 (**R-1128**) in the Historical
> landmark remodel pack (epic **R-1121**). This row now covers **St Mary's / the Dome Church**, which
> no LM row owns, plus one requirement that spans the whole compound: the cathedral **and** LM-04's
> castle must sit on the compiled relief from UF-07 (**R-1116**) and WB-04 (**R-976**), never on a
> fixed Y, and neither may edit relief to fit a model. This row owns the skyline plate set that
> proves it. Consume the LM-01 weathering kit (**R-1123**).
> See [pack README](README.md#ownership-seam).

Board row: **R-1122**. Priority: high. Depends on: **R-1116**, **R-1118**, **R-960**; inherited relief gates **R-976** and **R-1109**. Consume **R-967** (AR-09) if its approved set lands first.

## Player-facing goal

See the castle compound and the cathedral building site standing above the Lower Town, then climb to their distinct courts without finding floating walls or a flattened hill. The opening-phase hill is the Danish viceroy's seat and the bishop's precinct, not an automatically Order-held fortress. Owner: Map for anchor placement, Art for model fitting and Dev for existing loader bindings; QA independently accepts the climb. Slice: urban-form-landmarks.

## Why this is needed

Checked on 2026-09-30: content/maps/toompea_quarter.rrmap has **15 house records**, toompea_small_castle.rrmap **6**, and archbishops_garden.rrmap **2**. These are **23** existing houses, not two absent monumental sites. `castle_mass` is a **16 x 14-cell** house, `castle_keep_tower` a **9 x 9-cell** wall tower, and `cathedral_silhouette` a **20 x 12-cell** house. The outdoor castle already has named curtains, gate jambs and `castle_gate_arch`. Its developer door `to_small_castle` is already reciprocal with the inactive interior's `to_toompea_quarter` transition.

The cathedral style already carries `st_marys_construction_1343`. Its construction builder is in **scripts/map/view3d/map_view_mesh_builder_buildings.gd**, not solely in the church helper named by the old precedent. The registry recognises `cathedral_silhouette` by ID and `house.cathedral` by style, but does **not** list that existing primitive in `EXCEPTIONAL_PRIMITIVES`. The house mass and wall tower use different existing rendering paths; an asset overlay on both would double the castle. There is no `stone_keep` building token on these three maps, so the contract must preserve the actual castle IDs rather than inventing a replacement ID from AR-09 prose.

The map header and plateau datum still use **elevation=2.8**, approximately **2.44 m** at 0.87 m per world unit, with four retained `r454.*` elevation records. The **20-30 m** hill in history/dossiers/architecture/toompea-castle-and-upper-town.md belongs to WB-04/R-976 and UF-07/R-1116, not this model task. ADR 0023 and ADR 0025 both still say **Proposed, awaiting maintainer acceptance**. Their files being present is not acceptance.

## Deliverable

1. **Small Castle, `landmark.toompea_castle`.** Current state: placed procedural compound on **toompea_quarter**, including a domestic-style castle mass and separately rendered fortification pieces, not an absent site. Route choice: **consume AR-09's approved keep, hall, service, curtain and gate set**. If that set has not landed, an explicit AR-09 owner handoff and maintainer scheduling decision may delegate only these named exterior masses here; replace the existing house/fortification geometry with authored ADR 0025 B assets. Do not build a second castle through map_view_landmark_models.gd. The approved exterior model is partitioned into named components that bind once to existing building IDs and authored footprints.

   **1343 phase:** the Toompea dossier identifies the **1227-1229** Order-built Small Castle, Danish again from **1238**, and the viceroy's seat in April 1343 as `attested`. The report must separate construction origin from current jurisdiction. Exact keep, roof and range reconstruction is `plausible composite`; the row's first step for unresolved dimensions is a Canon Keeper-signed evidence sub-task. A dated later campaign handover does not change the opening exterior's authority by default. Target a low walled compound with separate keep, hall and service roofs, a legible forecourt and controlled gate, not a single oversize hall.

   **Exclusions:** no Tall Hermann in its final height, and do not backdate its first masonry **by 1371** into April 1343; no baroque Toompea palace wing, later palatial facade or monumental modern skyline. The ban is stronger than merely shortening a later tower. Do not create disputed knights compounds or western canonical hall rows. **B** primary masses use the budget below; LOD2 retains the approved keep, curtain and roof ridges. Collision stays the existing 2D footprint and gate aperture; no imported mesh collision and no model-driven navigation change. Preserve `castle_mass`, `castle_keep_tower`, all `castle_curtain_*`, both gate jambs, `castle_gate_arch`, `castle_courtyard`, `castle_close`, `sign.castle`, `to_small_castle` and `from_small_castle`. Bind UF-09's exact dedicated anchor on this map; `castle_courtyard` is not automatically that anchor unless UF-09 selects it.

2. **Dome Church, `landmark.toomkirik`.** Current state: `cathedral_silhouette` invokes the procedural construction-phase route on **toompea_quarter**. Route choice: **consume AR-09's approved St Mary's construction group**, or replace only that existing route after the same explicit handoff. Keep the facade API and ID, deleting or redirecting the replaced procedural geometry so only one group renders. Reconcile the already-authored `st_marys_construction_1343` key into the existing registry rather than introducing another primitive name.

   **1343 phase:** history/dossiers/religion/churches-and-religious-houses.md supports the **1330s** Gothic enlargement programme as `attested`; the precise April arrangement of unfinished bay, nave pillars, scaffold, lifting wheel and stone yard is `plausible composite`. Canon Keeper signs which parts are standing and which are under construction before Art production. Target an unmistakable church building site above an open episcopal close, with a distinct west front and an unfinished mass. Construction machinery must stay within the approved evidence and AR-09 handoff, not become a new gameplay system.

   **Exclusions:** no post-1343 completed cathedral nave presented as April fabric, no later chapels or tower, no **1779 baroque spire**, and no uniformly finished tourist cathedral. AR-09's "no completed east end" rule must be reconciled with the dossier's already-rebuilt choir/vestry by the first Canon-signed evidence sub-task, rather than deleting supported early fabric or inventing certainty. **B** primary mass and construction group use the budget below; LOD2 keeps the church roof, west front and visibly unfinished silhouette. Collision remains footprint-authored; the open close remains navigable. Preserve `cathedral_silhouette`, `cathedral_frontage`, `cathedral_close`, `cathedral_orchard`, `cathedral_steps`, `sign.cathedral` and all school/canon IDs. Bind only the exact UF-09 anchor, with the source-backed approach and `street_id` or justified null street address.

3. **Budget, quoted from ADR 0025 Decision 3.** Each B model: **60,000 / 18,000 / 4,000 triangles** for LOD0/1/2, switches at **60 / 140 world units**, never culled inside its map. All resident models of the Toompea B theme share the **180,000 LOD0 triangle** and **12 MiB** set cap; UF-12 cannot claim a second allowance beside AR-09. At most **8 material slots** and one **2048 x 2048** trim atlas per B model. Each building GLB is at most **6 MiB**, each texture **4 MiB**, tileable surfaces **1024 x 1024**, each map **64 building materials**, and all assets/buildings **96 MiB**. If AR-09 supplies subordinate K-L service ranges, their caps remain **14,000 / 4,500 / 900 triangles**, switches **40 / 90**, **6 shared material slots**, camera-far culling and no embedded K-part images; they are not primary castle/cathedral mass. Use authored LODs with visibility ranges, **3.0-unit margin**, fade disabled and minimum-tier distances multiplied by **0.6**. No alternate UF budget and no giant monolith used to evade a set cap.
4. **Height-field binding.** WB-04 owns relief; UF-07 owns the ways that climb it. Seat each approved model component on the compiled height field at its authored footprint. Test sampled ground contact, not a constant Y copied from the old 2.8 datum. Art fits plinths and lower courses to the approved surface without hiding the slope in a giant platform. No `grade`, `elevation_*`, `relief_*`, ramp, height-field or street edits here. If fitting fails, release this part with an evidence-backed WB-04/UF-07 amendment request; do not alter terrain to make the model fit.
5. **Register handoff.** Preserve UF-09's `id`, `owning_map_id`, `anchor_id`, `street_id`, `address_note`, `phase_1343`, `later_phase_excluded`, `model_tier`, `existing_geometry_ids`, `confidence`, `evidence_class` and `source_ids`. Set each site to `modelled` only when its exact anchor and approved GLB exist; fill `asset_path` and remove its absence grace. `absent` and `anchored` are interim statuses, not synonyms for procedural quality. Store the current implementation state and renderer reconciliation in the linked report until UF-09 explicitly admits those fields. Do not silently extend its no-extra-keys JSON schema.

## Allowed files

Exact paths for later implementation, not permission to implement during this rewrite. Consumed AR-09 assets remain at their approved paths and are read-only here; the fallback assets below require the explicit handoff above.

- assets/buildings/landmarks/toompea_castle/toompea_castle_1343.glb
- assets/buildings/landmarks/toompea_castle/toompea_castle_1343.glb.import
- assets/buildings/landmarks/toomkirik/toomkirik_1343.glb
- assets/buildings/landmarks/toomkirik/toomkirik_1343.glb.import
- generated/blender/toompea_landmarks_v1/toompea_landmarks_1343.blend
- tools/generate_toompea_landmarks.py
- scripts/map/view3d/map_view_mesh_builder_building_registry.gd
- scripts/map/view3d/map_view_mesh_builder_buildings.gd
- scripts/map/view3d/map_view_mesh_builder_building_houses.gd
- scripts/map/view3d/map_view_mesh_builder_building_fortification.gd
- content/maps/toompea_quarter.rrmap
- content/world/reval_outdoor_layout.json
- tests/godot/test_toompea_landmarks.gd
- tests/godot/test_toompea_landmarks.gd.uid
- tools/capture_uf12_toompea.gd
- tools/capture_uf12_toompea.gd.uid
- docs/data/reval_landmark_register_1343.json
- docs/reports/reval_landmark_placement_1343.md
- docs/reports/uf12_toompea.md
- assets/SOURCES.csv
- docs/HISTORICAL_AUDIT.md

## Constraints and non-goals

- R-1109 must clear ADR 0023's explicit acceptance gate, WB-04 must deliver relief and R-1116 must deliver the climb. R-960 must likewise clear ADR 0025. Its Decision 6 defers AR-09 until AR-05..08 visual acceptance; UF-12 cannot bypass that trade by renaming the same work. Obtain a maintainer decision or consume the approved set, with no active worker claim held on a blocked dependency.
- Preserve all `r454.*` records, gate and approach anchors, transition/spawn IDs and both inactive map states. No edit to toompea_small_castle.rrmap, archbishops_garden.rrmap or their interiors. The outdoor map allowance is for anchor/model binding only, not relief or a new forecourt footprint.
- P0-040 authorises only the listed new files, shared materials and in-house deterministic generators. Every new asset/source file has an assets/SOURCES.csv row, source rights and checksum. Additional textures, file splits, catalogue changes or ornament require an exact-path amendment. Image-to-3D primary geometry is prohibited.
- Use existing building and fortification routes. No second renderer and no invented primitive. If a new `view_landmark` kind is later proposed, first authorise scripts/map/map_definition.gd (`VIEW_LANDMARK_KINDS`), scripts/map/map_blueprint_compiler_build.gd (`_compile_landmark`) and scripts/map/map_blueprint_compiler.gd (`LANDMARK_OVERRIDE_KEYS`) together, plus tests. The current contract needs none.
- Any reval_outdoor map edit rebuilds content/world/reval_outdoor_layout.json in the same commit. Serialize the shared renderer, layout, register and provenance paths with other UF and AR rows. No Fat Margaret, later skyline filler, interior, quest, activation or save-state work.

## Verification

Run after implementation from the repository root. The asset-governance scripts exist now; the focused test/capture tool are row deliverables and R-1118 supplies the register verifier.

```bash
sed -n '1,12p' docs/adr/0023-terrain-relief-as-gameplay.md
sed -n '1,12p' docs/adr/0025-architectural-asset-pipeline.md
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_toompea_landmarks,test_toompea_quarter_prototype_map,test_archbishops_garden_prototype_map,test_toompea_small_castle_map
godot --headless --path . --script tools/validate_map_blueprints.gd
godot --headless --path . --script tools/run_godot_tests.gd
godot --headless --path . --script tools/build_world_layout.gd
godot --headless --path . --script tools/build_world_layout.gd -- --check
python3 tools/verify_world_layout.py
python3 tools/verify_landmark_register.py
python3 tools/validate_asset_sources.py
python3 tools/verify_asset_lint.py
python3 tools/verify_runtime_glb_budget.py
python3 tools/verify_storage_hygiene.py
python3 tools/verify_map_composition.py
python3 tools/verify_map_audit.py
python3 tools/verify_map_activation.py
python3 tools/verify_map_conversion_plan.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

`test_toompea_landmarks` checks both exact anchors, approved GLBs, three LODs, budgets, all preserved IDs and one render path per component. Assert the existing cathedral primitive is recognised by the registry. Sample ground contact against compiled heights, then use a height-field fixture with changed samples to prove models follow ground rather than a constant Y. Assert the production height field and relief records are unchanged by this row. A missing field, floating plinth or duplicate castle is a failing fixture. Compare walkability bit-for-bit; test the Small Castle door in both directions, including `small_castle_entry` and `from_small_castle`. Keep the two climbs and all patrol points passable, with maps still inactive.

The new capture tool records fixed transforms and implements the following plate names and switches. Capture **Lower Town looking up, harbour looking toward the hill, plateau looking across both precincts**, the castle gate and cathedral work yard, plus 6/12-unit gameplay views and maximum orthographic zoom. `lod_dolly` writes a ten-second timed frame sequence through both LOD distances.

```bash
for plate in lower_town harbour plateau castle_gate cathedral_yard near6 near12 far lod_dolly; do
  for condition in noon overcast dusk midnight; do
    tools/godot_render.sh --rendering-method gl_compatibility --script tools/capture_uf12_toompea.gd -- --phase after --plate "$plate" --condition "$condition" --tier recommended --output "/tmp/uf12_after_${plate}_${condition}_gl_recommended.png"
  done
done
godot --headless --path . --script tools/capture_uf12_toompea.gd -- --verify-distinct /tmp/uf12_after
```

Repeat for the pre-change revision with `before` in phase and filenames, then minimum tier and Metal (`--rendering-method mobile --rendering-driver metal`) on the supported host with distinct suffixes. Never open a visible Godot window. Each plate uses one process, especially day/night comparisons. Verify nonempty files, hashes and pixel differences before reviewing the set; identical noon/night outputs fail. Conditions are clear noon, overcast rain, dusk and moonlit/torch-lit midnight. Use 1280 x 720 PNGs and the ADR 1.5 MiB active-image soft cap, retain raw evidence outside the repo and record durable evidence links and hashes in docs/reports/uf12_toompea.md.

Canon Keeper signs both phases, jurisdiction and the early choir/unfinished-nave decision. A maintainer-named human Art reviewer records accept/amend/reject with name and ISO date against all seven ADR 0025 checks, including ground contact and LOD transitions. The hill must dominate the view and the cathedral must read as a building site. Independent QA signs climb, door, unchanged relief and capture integrity. Report frame p95 regression **<= 10%**, building draw calls **<= 450/300**, submitted triangles **<= 2.0M/0.8M** and assembly **<= 4 ms** for recommended/minimum. Do not claim the R-653 minimum target gate from a different host.

## Doc updates

Update the two register rows, linked placement report, row evidence report and assets/SOURCES.csv. Record consumed AR-09 files, current and replaced renderer paths, exact anchors, sampled ground heights, dated phase exclusions and human reviews. Audit changes require Canon Keeper approval. Producer records the inherited relief/ADR gates and the AR scheduling decision on R-1122. The supplied board export contains **no UF-12 repository-state correction block**, despite the rewrite brief saying all four have one; this contract supplies the verified correction without editing that export, an ADR, TODO.md or the pack README.

## TODO.md line

- [ ] R-1122 | deps: R-1116, R-1118, R-960; inherits R-976/R-1109; consume R-967 by approved handoff | deliverable: upgrade castle and cathedral through existing render paths with B-tier 1343 models, exact register anchors and compiled-height-field seating, preserving the Small Castle door and all relief | verify: test_toompea_landmarks; full map/world/asset gates; unchanged relief and walkability; distinct skyline GPU plates; Canon, named human Art and independent QA acceptance
