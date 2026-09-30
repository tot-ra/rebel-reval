# UF-11: St Olaf's, Holy Spirit, Town Hall and Great Guild site exteriors

> **Scope narrowed, 2026-09-30.** The Town Hall moved to **R-1135** and Holy Spirit to LM-03
> (**R-1126**) in the Historical landmark remodel pack (epic **R-1121**). This row now covers only
> **St Olaf's** and **the Great Guild**, which no LM row owns, and must consume the LM-01 weathering
> kit (**R-1123**) rather than authoring its own wear. The Town Hall and Holy Spirit material below
> is kept as reference for LM-03 and R-1135, not as work for this row.
> See [pack README](README.md#ownership-seam).

Board row: **R-1120**. Priority: high. Depends on: **R-1118**, **R-1115**, **R-960**. Consume **R-965** (AR-07) and **R-968** (AR-10) if their approved assets land first; their production work is not duplicated here.

## Player-facing goal

Recognise the northern parish, the market chapel and the civic hall by their different 1343 silhouettes. Find a qualified Great Guild meeting site without seeing a fifteenth-century guild palace. This is an upgrade and placement-binding row, not the creation of four missing buildings. Owner: Map for registered placement, Art for the named exteriors, Dev for existing loader bindings; independent QA accepts the routes. Slice: urban-form-landmarks.

## Why this is needed

Checked on 2026-09-30. content/maps/market_civic_quarter.rrmap contains **52 house records**, including `town_hall_mass` (**24 x 14 cells**, `town_hall_1343`), `church_silhouette` (**14 x 10**, `holy_spirit_chapel_1343`), `holy_spirit_hospital` (**16 x 10**) and `guild_frontage` (**12 x 10**). Holy Spirit's chapel is `church_silhouette`, not its hospital. scripts/map/view3d/map_view_town_hall_model.gd already builds the hall, and scripts/map/view3d/map_view_mesh_builder_building_registry.gd routes these civic IDs and styles through the exceptional-building boundary.

content/maps/monastery_quarter.rrmap contains **159 house records**, not the old AR-07 count of 29. It places `st_olaf_silhouette` (**22 x 14 cells**), `olaf.close`, `olaf_precinct_west`, `olaf_precinct_east`, `great_guild_front` (**20 x 8**) and `anchor guild_frontage`. scripts/map/view3d/map_view_mesh_builder_churches.gd recognises St Olaf by ID and emits `st_olaf_1343`. Its four buttress positions and five lancet positions are repeated on **two sides**, giving **eight buttress and ten lancet meshes**, not four and five total. `st_olaf_1343` is renderer metadata, not one of the registry's nine primitive keys.

The Great Guild is not proven to be a dedicated procedural landmark simply because `house.guild` has a route. Its monastery mass is an ordinary merchant style; the civic `guild_frontage` is a different building with the `to_guild_hall` door to st_olafs_guild_hall.rrmap. UF-09 must distinguish these, not identify the St Olaf craft-guild interior as the Great Guild. Existing geometry, interior doors and dedicated registered exterior assets are three separate facts.

## Deliverable

1. **St Olaf's, `landmark.oleviste`.** Current implementation: procedural church on **monastery_quarter**, recognised by ID despite the generic church style. Route choice: **consume AR-07's approved church set** if delivered; otherwise replace this ID's procedural assembly with one authored ADR 0025 B model at the same boundary. Never render both. Preserve `st_olaf_silhouette`, `st_olaf_frontage`, both `olaf_precinct_*` ranges, `olaf.close`, `pikk_street_spine` and `to_oleviste_church`. Bind the exact dedicated UF-09 `anchor_id`; `st_olaf_frontage` may serve only if UF-09 explicitly selects it, not by proximity.

   The church dossier records completed vault work around **1330** as `attested`, but the west tower's April state is unresolved: it describes an older massive west tower as `plausible composite` and also a **1364** lower-tower date. **First step: a Canon Keeper-signed evidence sub-task resolves the tower phase before Art builds it.** The target is a compact vaulted church with a modest, source-supported west mass, not a mandatory completed later tower. Exact reconstruction is `plausible composite`. Exclude the post-1433 basilica, later chancel, and **15th/16th-century Oleviste spire**. B LOD2 keeps the approved west mass and ridge. Collision remains the compiled footprint, with the **Pikk-spine bypass lane intact** and the existing interior door round-trip unchanged.

2. **Holy Spirit, `landmark.holy_spirit`.** Current implementation: `church_silhouette` uses the known `holy_spirit_chapel_1343` primitive on **market_civic_quarter**, beside `holy_spirit_hospital` and `holy_spirit.close`. Route choice: **consume AR-10's chapel and hospital set** if approved, otherwise replace only these procedural primary masses through the existing exceptional route. Preserve those three IDs, `holy_spirit_frontage` and `to_holy_spirit_church`; bind UF-09's dedicated anchor at the chapel/yard approach, not the hospital as a substitute church.

   history/dossiers/religion/churches-and-religious-houses.md supports the priest/church in **1316/1319** as `attested`, with two-aisle hall proportions and hospital-court arrangement a `plausible composite`. Target a low twin-aisle hall, small choir and associated alms range around open court. Exclude the **1360 vaults and tower**, later enlargement and unproven ornamental programme; no third aisle. The chapel and institutional hospital primary masses are **B**, not a K house scaled up. Their LOD2 keeps hall, choir and court relationships. Collision, door axis, yard access and interior round-trip stay bit-identical for model replacement.

3. **Town Hall, `landmark.town_hall`.** Current implementation: the placed `town_hall_mass` uses `town_hall_1343`, with a dedicated builder in map_view_town_hall_model.gd. Route choice: **consume AR-10's accepted 1343 hall** or replace this builder's geometry with the authored B hall. Do not add a landmark overlay on top of it. Preserve `town_hall_mass`, `town_hall.forecourt`, `town_hall_edge`, `sign.town_hall` and the snapped `to_town_hall` door; the exact register anchor must resolve on **market_civic_quarter**.

   The AR-10 contract and docs/reports/town_hall_1343_remodel.md prescribe a weathered **one-storey hall without an arcade**. Carry that reconstruction as `plausible composite`, not an attested measured elevation. Canon Keeper signs the phase evidence before production. Target a low civic hall with a forum-facing portal, gable, loft and restrained service features, at least matching the current builder's wear and material readability. Exclude the **post-1402 Town Hall rebuilding**, specifically the **1402-04 arcade and tower**, and later showpiece facade. B LOD2 retains the low hall and gable. Keep footprint-derived collision and the exact door axis; no change to town_hall.rrmap.

4. **Great Guild meeting site, `landmark.great_guild`.** Current implementation: two different frontage candidates, not one confirmed 1343 hall. UF-09 must sign the exact site and address before this part starts. Proposed primary owner is **monastery_quarter**, using the generic `great_guild_front`; if UF-09 chooses civic ownership, record the evidence and do not create a duplicate monastery institution. Preserve both `great_guild_front` and the civic `guild_frontage`, the monastery anchor of that name, and all existing doors. The nonselected candidate remains generic fabric.

   Route choice: **consume an AR-10 K-L wide-frontage deliverable**, or assemble this one generic frontage from the approved AR-04 catalogue. No bespoke guild-palace model, no new guild renderer. A pre-1407 meeting room/frontage is `plausible composite`; exact location and institutional identification require the first Canon-signed evidence sub-task if UF-09 has not resolved them. Target a wide, sober merchant meeting frontage, not a fourth skyline tower. Explicitly exclude the **1407-10 Great Guild Hall**, Brotherhood/Blackheads facades and treating the craft-guild use first recorded in **1363** as attested for 1343. Model tier is **K-L**, as UF-09 requires. LOD2 is a merged plinth/wall/gable/roof proxy without openings. Collision and generic guild-door transitions remain unchanged. Bind only the dedicated register anchor on the selected map; the existing St Olaf guild interior is not relabelled as the Great Guild.

5. **ADR 0025 budgets for every model above.** B: **60,000 / 18,000 / 4,000 triangles** at LOD0/1/2; switches **60 / 140 world units**; never culled inside its map; at most **8 material slots** and one **2048 x 2048** trim atlas. K-L: **14,000 / 4,500 / 900 triangles**; switches **40 / 90**; camera-far culling; at most **6 shared material slots** and **no embedded images in K parts**. A resident B theme set is capped at **180,000 LOD0 triangles** and **12 MiB**, not a fresh budget for each UF wrapper around an AR set. Any building GLB is at most **6 MiB**, each texture **4 MiB**, tileable surfaces **1024 x 1024**, all building assets **96 MiB**, and each map **64 distinct building materials**. Authored LOD meshes use visibility ranges, a **3.0-unit margin**, no fade and minimum-tier switch distances multiplied by **0.6**. B far proxies retain silhouette features; importing generated LODs alone does not pass.
6. **Register and renderer proof.** Use UF-09's exact fields and status vocabulary. Each accepted site resolves `owning_map_id`, `anchor_id`, `asset_path`, `street_id`, `phase_1343`, `later_phase_excluded`, `model_tier`, `existing_geometry_ids`, `confidence`, `evidence_class` and `source_ids`. `modelled` requires an existing approved GLB and exact anchor; remove only that site's absence grace. Procedural correction alone would remain `anchored` with null asset and would not close this row. Describe `generic_house_style`, `procedural_primitive` and `authored_model` implementation states in the linked report unless the UF-09 schema is explicitly amended. Tests must prove one render path per existing building. No new primitive names are needed.

## Allowed files

Exact paths for the later implementation are below. Fallback GLBs are used only if the AR owner explicitly delegates these landmark masses; approved AR assets are consumed in place, never copied here. This rewrite changes only this contract.

- assets/buildings/landmarks/oleviste/oleviste_1343.glb
- assets/buildings/landmarks/oleviste/oleviste_1343.glb.import
- assets/buildings/landmarks/holy_spirit/holy_spirit_1343.glb
- assets/buildings/landmarks/holy_spirit/holy_spirit_1343.glb.import
- assets/buildings/landmarks/town_hall/town_hall_1343.glb
- assets/buildings/landmarks/town_hall/town_hall_1343.glb.import
- assets/buildings/landmarks/great_guild/great_guild_frontage_1343.glb
- assets/buildings/landmarks/great_guild/great_guild_frontage_1343.glb.import
- generated/blender/reval_landmarks_v1/reval_landmarks_1343.blend
- tools/generate_reval_landmarks.py
- scripts/map/view3d/map_view_mesh_builder_building_registry.gd
- scripts/map/view3d/map_view_mesh_builder_buildings.gd
- scripts/map/view3d/map_view_mesh_builder_churches.gd
- scripts/map/view3d/map_view_mesh_builder_building_houses.gd
- scripts/map/view3d/map_view_town_hall_model.gd
- content/maps/monastery_quarter.rrmap
- content/maps/market_civic_quarter.rrmap
- content/world/reval_outdoor_layout.json
- tests/godot/test_reval_landmarks.gd
- tests/godot/test_reval_landmarks.gd.uid
- tools/capture_uf11_landmarks.gd
- tools/capture_uf11_landmarks.gd.uid
- docs/data/reval_landmark_register_1343.json
- docs/reports/reval_landmark_placement_1343.md
- docs/reports/uf11_civic_and_parish.md
- assets/SOURCES.csv
- docs/HISTORICAL_AUDIT.md

## Constraints and non-goals

- ADR 0025 remains **Proposed, awaiting maintainer acceptance**. R-960 must record a human decision before code or production art. Its Decision 6 defers AR-10 until AR-05..08 pass visual acceptance. UF-11 is not a way around that scope trade: consume approved work or obtain an explicit maintainer-approved scheduling/delegation decision before the civic replacement. Do not silently turn the conditional AR dependencies into an authorisation to build their kit twice.
- Preserve every stable ID and all reciprocal doors into oleviste_church.rrmap, holy_spirit_church.rrmap, town_hall.rrmap and st_olafs_guild_hall.rrmap. These interiors are read-only. No activation, map relocation into north_quarter, unrelated house replacement or guild narrative rewrite.
- P0-040 permits only the listed new files. Use shared AR surfaces; additional GLBs, textures or catalogue edits require an exact-path amendment. Every new asset/source file needs assets/SOURCES.csv provenance, generator and checksum. No image-to-3D primary mass or external ornament is authorised here.
- No new view-landmark kind or parallel map_view_landmark_models.gd. A change of route first requires exact allowed paths for `MapDefinition.VIEW_LANDMARK_KINDS`, `_compile_landmark` and `LANDMARK_OVERRIDE_KEYS`, plus round-trip tests, as agents/rebel-map/playbook.md requires. Existing building-ID dispatch is sufficient here.
- Keep the Pikk bypass, both parish closes and town_hall.forecourt open. Rebuild content/world/reval_outdoor_layout.json in the same commit as any map edit. Serialize shared renderer, monastery, register, provenance and layout paths with R-285, AR-07, AR-10, UF-10 and UF-13. Do not introduce Fat Margaret to improve a harbour silhouette.

## Verification

Run from the repository root after implementation. The named test and capture tool are new deliverables; the register gate comes from R-1118. All four asset-governance scripts already exist.

```bash
grep -c '^building .* house ' content/maps/market_civic_quarter.rrmap content/maps/monastery_quarter.rrmap
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_reval_landmarks
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

`test_reval_landmarks` checks four registered sites, exact anchors, valid approved GLBs, correct B/B/B/K-L tiers, three authored LODs, budgets and one render route per building. It traverses all four existing interior doors in both directions, checks local and destination spawn IDs, preserves route/anchor accounting and proves the Pikk bypass remains passable. Negative cases include unknown primitive, missing asset, doubled model and confusing the Great Guild site with the craft-guild interior. Compare walkability bit-for-bit before and after asset replacement; any desired footprint change needs a separately reviewed Map amendment.

Capture matched before/after plates at the **harbour skyline, forum, Pikk approach and each of the four frontages**, not just a showcase scene. Record camera transforms at 6 and 12 units, the street axis, and maximum orthographic zoom in docs/reports/uf11_civic_and_parish.md. The new capture tool implements these plate names and the arguments below, plus `--verify-distinct` and `--plate lod_dolly` for a ten-second timed sequence through both switches.

```bash
for plate in harbour forum pikk oleviste holy_spirit town_hall great_guild near6 near12 far lod_dolly; do
  for condition in noon overcast dusk midnight; do
    tools/godot_render.sh --rendering-method gl_compatibility --script tools/capture_uf11_landmarks.gd -- --phase after --plate "$plate" --condition "$condition" --tier recommended --output "/tmp/uf11_after_${plate}_${condition}_gl_recommended.png"
  done
done
godot --headless --path . --script tools/capture_uf11_landmarks.gd -- --verify-distinct /tmp/uf11_after
```

Repeat on the pre-change revision with `before` in the phase and filenames. Repeat for minimum tier and for Metal with `--rendering-method mobile --rendering-driver metal` on a capable host, using distinct suffixes. Each plate has its own Godot process for day/night calibration; no visible window, no headless dummy pixel capture. Noon is clear, overcast includes rain, midnight includes moonlight and torches. Verify nonempty files, hashes and actual pixel differences before review; identical condition plates fail. Capture 1280 x 720, observe the ADR 1.5 MiB active-image soft cap, keep raw files outside the repo and link retained evidence with hashes.

Canon Keeper signs each phase and the tower/site decisions. A named human designated by the maintainer records accept/amend/reject and ISO date against all seven ADR 0025 visual checks. Acceptance requires three distinguishable civic/parish silhouettes and a sober generic guild frontage, not four invented monuments. Independent QA signs door round-trips, Pikk traversal and capture integrity. Report frame p95 regression **<= 10%**, building draw calls **<= 450/300**, submitted triangles **<= 2.0M/0.8M**, and per-building assembly **<= 4 ms** for recommended/minimum. R-653 still gates actual minimum-target acceptance.

## Doc updates

Update the four register entries, placement report, row evidence report and provenance only. Name the consumed AR asset and the deleted or redirected procedural path for each building. Canon Keeper approves audit changes; the Producer records AR ownership and sequencing decisions on R-1120. The board correction requesting implementation-state fields conflicts with UF-09's current no-extra-keys schema: do not guess new keys; resolve that upstream before relying on such fields. No TODO.md or shared pack README edit occurs in this rewrite.

## TODO.md line

- [ ] R-1120 | deps: R-1118, R-1115, R-960; consume R-965/R-968 by approved handoff | deliverable: upgrade and bind Oleviste, Holy Spirit, Town Hall and a qualified K-L Great Guild meeting frontage through single existing render routes, preserving doors and the Pikk bypass | verify: test_reval_landmarks; full map/world/asset gates; four door round-trips; distinct GPU plates; Canon, named human Art and independent QA acceptance
