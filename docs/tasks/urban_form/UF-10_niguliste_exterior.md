# UF-10: St Nicholas' (Niguliste) 1343 exterior and churchyard

> **Scope narrowed, 2026-09-30.** The model, the 1343 dossier and the weathering moved to LM-08
> (**R-1134**) in the Historical landmark remodel pack (epic **R-1121**). LM-08 states that
> "placement needs a map task with named files before any rrmap edit" - this row is that map task.
> Keep the placement, anchor, churchyard reconciliation, truthful `sign.niguliste` and layout rebuild
> below. Ignore anything below that authors the model, the dossier or the wear, and consume the LM-01
> weathering kit (**R-1123**) instead. See [pack README](README.md#ownership-seam).

Board row: **R-1119**. Priority: high. Depends on: **R-1118**, **R-1114**, **R-960**; **R-1115** before the South Quarter placement commit.

## Player-facing goal

Follow the existing sign to St Nicholas', see the church from its own lane, and enter a recognisable merchant parish churchyard. This is the one missing church, not another replacement of an existing landmark. Owner: Map for placement, Art for the exterior and Dev for its single renderer binding; independent QA accepts the walk. Slice: urban-form-landmarks.

## Why this is needed

Checked on 2026-09-30: a search of content/maps and scripts/map/view3d finds **zero** Niguliste church buildings, dedicated anchors, landmark statements or renderer entries. There are **six** adjacent references: content/maps/south_quarter.rrmap has `niguliste_close` (grass, **31 x 19 cells**), `niguliste_lane` (a dirt stroke, thickness **3**), `niguliste_row` and `niguliste_chapter_house`; content/maps/market_civic_quarter.rrmap has `niguliste_corner_house` and `sign.niguliste`, reading "to st nicholas" and pointing west. A churchyard and a sign are not a church.

The route for exceptional buildings already exists. scripts/map/view3d/map_view_mesh_builder_building_registry.gd lists **seven styles and nine primitives**, including `stone_church`. scripts/map/view3d/map_view_mesh_builder_churches.gd supplies existing parish-church builders. The board's proposed map_view_landmark_models.gd does not exist; there is no reason to create a competing renderer merely to close this hole.

## Deliverable

1. **Placement decision before art.** Use `landmark.niguliste` from UF-09. This contract selects **south_quarter** as the single primary owner, using its existing close and lane rather than duplicating the church beside the civic sign. UF-09 and the Canon Keeper must ratify that owner and its exact `anchor_id`, entrance and `street_id` before placement. A contrary register decision blocks this write set for amendment; it does not permit a second copy. R-1114 supplies the civic approach; R-1115 must also land because the church itself uses the South Quarter street plan. Prove the sign's westward approach reaches that one site through the compiled seam network, rather than assuming the two map rectangles touch at the sign.
2. **St Nicholas' exterior, current state: absent.** Author a new ADR 0025 **B** church set, not a scaled house and not another procedural box. Bind a new church building to the exact UF-09 anchor through the existing exceptional-building boundary, using the already recognised `stone_church` primitive and an explicit ID-to-asset binding. Preserve the register's stable site ID separately from building and anchor IDs. Do not author an unregistered `niguliste_1343` primitive. Reuse approved AR parts for secondary work; no new church kit or parallel asset catalogue.
3. **1343 phase and silhouette.** history/dossiers/religion/churches-and-religious-houses.md records the late-13th-century nave with two aisles, square chancel, sacristy and low west tower, the first-half-14th-century north porch and the **1342** St Barbara chapel record as `attested`. The exact April arrangement, porch proportions and cemetery placement remain `plausible composite` until reviewed. Target a stocky tower, compact hall, thick limestone walls and restrained openings. Defensive early fabric is supported; do not turn that into an unsupported claim that the parish was still an active merchant fortress in April. The dossier says that role faded after enclosure by the town wall. The first step for any unresolved dimension or chapel placement is a bounded evidence sub-task signed by the Canon Keeper, not a confident model guess.
4. **Later state excluded.** No late-Gothic Niguliste nave, **1405-1420** enlarged basilica choir, polygonal ambulatory, later tall spire, late tracery package or **1470s+** St Matthew enlargement. No Hermen Rode altar or interior commission. St Barbara's attestation is not a licence to reconstruct an exact surviving later chapel. Record each exclusion in `later_phase_excluded` with cited reasoning.
5. **Budget and LODs, quoted from ADR 0025 Decision 3.** Each **B model** is capped at **60,000 / 18,000 / 4,000 triangles** for LOD0/1/2, switching at **60 / 140 world units**, and is **never culled inside its map**. The resident B theme set is capped at **180,000 LOD0 triangles** and **12 MiB**; no single building GLB exceeds **6 MiB**. At most **8 material slots** and one **2048 x 2048** trim atlas per B model; shared surface families are at most **1024 x 1024**, each texture at most **4 MiB**. Keep at most **64 building materials per map** and **96 MiB** across assets/buildings. Authored meshes, not import-generated LOD alone, meet the contract. Use visibility ranges with a **3.0-unit margin**, fade disabled; minimum-tier distances are **0.6** times the listed distances. LOD2 retains tower, gables and roof ridge. Budget this set with its AR family, not as free additional headroom.
6. **Precinct and collision.** The exterior GLB contains named church and boundary components, with its three authored LODs. The burial ground stays open, unroofed and free of houses, with a wall and one legible gate. The Map owner specifies the new building and wall footprints before Art fits geometry to them. Collision and navigation derive from that authored 2D source, never imported render-mesh collision. Record the deliberate new blocked cells and prove all unrelated routes, patrols, spawns and anchors remain reachable. Add owned `open_regions` to the South Quarter authoring contract for the remaining churchyard ground, without lowering a signed density band.
7. **Register handoff.** Preserve the UF-09 fields `owning_map_id`, `anchor_id`, `street_id`, `address_note`, `phase_1343`, `later_phase_excluded`, `model_tier`, `existing_geometry_ids`, `confidence`, `evidence_class` and `source_ids`. Use only `absent`, `anchored`, `modelled` for `status`; after the anchor and approved GLB both resolve, set `modelled`, fill `asset_path` and remove this row's task-bound absence grace. A temporary anchor-only delivery is `anchored` with null `asset_path`, not acceptance of this row. Keep implementation-state and renderer details in the linked placement report until UF-09's schema explicitly admits them; do not add undocumented JSON fields.

## Allowed files

Later implementation is limited to these exact paths. This rewrite changes only this contract.

- assets/buildings/landmarks/niguliste/niguliste_1343.glb
- assets/buildings/landmarks/niguliste/niguliste_1343.glb.import
- generated/blender/niguliste_v1/niguliste_1343.blend
- tools/generate_niguliste.py
- scripts/map/view3d/map_view_mesh_builder_building_registry.gd
- scripts/map/view3d/map_view_mesh_builder_churches.gd
- scripts/map/view3d/map_view_mesh_builder_buildings.gd
- content/maps/south_quarter.rrmap
- content/maps/market_civic_quarter.rrmap
- docs/data/south_quarter_authoring_contract.json
- content/world/reval_outdoor_layout.json
- tests/godot/test_niguliste_landmark.gd
- tests/godot/test_niguliste_landmark.gd.uid
- tools/capture_uf10_niguliste.gd
- tools/capture_uf10_niguliste.gd.uid
- docs/data/reval_landmark_register_1343.json
- docs/reports/reval_landmark_placement_1343.md
- docs/reports/uf10_niguliste.md
- assets/SOURCES.csv
- docs/HISTORICAL_AUDIT.md

## Constraints and non-goals

- **ADR 0025 is Proposed, awaiting maintainer acceptance**, not accepted because its file was merged. R-960 must record the human decision before production art or landmark code lands. Respect its scope trade and AR ownership; any conflict is a decision blocker, not permission to start a second kit.
- P0-040 applies to the exact files above. Use shared materials without new texture files. A split into additional GLBs or new textures requires an amended exact asset list before authoring. Record a source and rights row for every new asset/source file, with deterministic generator and checksum. No image-to-3D primary geometry; no external ornament is needed by this contract.
- Preserve all six existing Niguliste references and every other stable map ID. The civic edit is limited to making the existing sign's direction truthful, not moving civic frontage. Keep both maps' activation states unchanged. No interior, stub map, new quest or NPC work.
- No new `view_landmark` kind is required. If that choice changes, first amend this contract for scripts/map/map_definition.gd (`VIEW_LANDMARK_KINDS`), scripts/map/map_blueprint_compiler_build.gd (`_compile_landmark` field copy), and scripts/map/map_blueprint_compiler.gd (`LANDMARK_OVERRIDE_KEYS`), with round-trip tests. map_types.gd alone is not sufficient.
- Any reval_outdoor `.rrmap` edit requires rebuilding the world layout in the same commit. Serialize shared map, renderer, register, provenance and layout writes with UF-06, UF-11 and UF-13. No Fat Margaret or other later skyline landmark may be added as context.

## Verification

Run from the repository root after implementation; the four asset-governance tools below already exist. The landmark verifier is supplied by R-1118; the test and capture tool are this row's deliverables, not commands claimed to pass today.

```bash
rg -n 'niguliste|st_nicholas' content/maps scripts/map/view3d
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_niguliste_landmark
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

The focused test resolves exactly one church, one registered anchor and one approved GLB. It checks three authored LODs, budgets, absence of a parallel renderer and unsupported primitive, a passable churchyard gate, sign-to-entrance reachability, and no unrelated ID or route loss. Test an absent asset and wrong anchor as failures. QA compares the actual geometry with the exclusions; metadata assertions alone cannot establish its historical form.

The new capture tool accepts `--phase`, `--plate`, `--condition`, `--tier`, `--output` and `--verify-distinct`. Record fixed gameplay-camera transforms in docs/reports/uf10_niguliste.md. Use street, gate, inside-close and district-silhouette plates, plus 6-unit and 12-unit third-person views and a ten-second dolly through both LOD switches. For each before/after state, run:

```bash
for plate in street gate close skyline near6 near12 lod_dolly; do
  for condition in noon overcast dusk midnight; do
    tools/godot_render.sh --rendering-method gl_compatibility --script tools/capture_uf10_niguliste.gd -- --phase after --plate "$plate" --condition "$condition" --tier recommended --output "/tmp/uf10_after_${plate}_${condition}_gl_recommended.png"
  done
done
godot --headless --path . --script tools/capture_uf10_niguliste.gd -- --verify-distinct /tmp/uf10_after
```

The dolly option writes a timed frame sequence beside its named output. Repeat the same command with `--phase before` and matching filename prefix on the pre-change revision; repeat for minimum tier and Metal (`--rendering-method mobile --rendering-driver metal`) on the supported host, with distinct output suffixes. Each invocation is one Godot process per plate or dolly, never a visible window. The verify mode checks nonempty images, hashes and pixel differences for matched conditions before review; identical noon/night plates fail. Keep raw evidence outside the repository and link retained evidence with hashes from the report. Use 1280 x 720 plates and the ADR 0025 1.5 MiB active-image soft cap.

Canon Keeper signs the evidence and 1343 phase. A maintainer-named human Art reviewer records accept/amend/reject, name and ISO date against all seven ADR 0025 visual checks, including a church rather than a large house. Independent QA signs the sign-to-gate walk, unchanged unrelated routes and capture integrity. Measure ADR frame p95 regression at no more than **10%**, building draw calls at **450/300**, and submitted triangles at **2.0M/0.8M** for recommended/minimum; no target-device acceptance is inferred from another host (R-653).

## Doc updates

Update only this landmark's register entry and linked placement report, the row's evidence report and provenance. Canon Keeper owns any audit claim changes; this contract cannot self-approve them. Record the chosen owner, seam route, exact anchor, collision delta, confidence and excluded later phases. Producer updates R-1119 and its R-1115 placement dependency in the task board. TODO.md is not edited by this rewrite or by the asset worker.

## TODO.md line

- [ ] R-1119 | deps: R-1118, R-1114, R-1115, R-960 | deliverable: one B-tier Niguliste exterior on south_quarter with registered anchor, open churchyard, truthful civic sign and a single existing-boundary asset route | verify: test_niguliste_landmark; full map/world/asset gates; sign-to-gate walk; distinct GPU plates; Canon, named human Art and independent QA acceptance
