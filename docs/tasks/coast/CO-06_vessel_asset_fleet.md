# CO-06: Authored vessel fleet replacing the primitive boat builders

Board row: **R-953**. Priority: high. Depends on: CO-05.

## Player-facing goal

Every boat on the Reval coast is recognisably a fourteenth-century Baltic craft, and no two are
identical. The Kalamaja beach has small clinker fishing boats of two sizes hauled up and moored, the
roadstead has cogs that read as heavy cargo ships, the piers have open rowing boats, and the beach
landings have a lighter transferring cargo. Hull wear, tar, paint, patched planks, nets, baskets and
cargo differ between hulls, so the harbour looks like a working harbour and not a copy-paste row.

## Why this is needed

`scripts/map/view3d/map_view_fishing_boat_builder.gd` and
`scripts/map/view3d/map_view_merchant_boat_builder.gd` are the entire fleet: two designs, assembled
from `Primitives.box` / `Primitives.cylinder` / spars with flat role materials (`&"wood"`, `&"timber"`,
`&"plaster"` for the sail, `&"hay"` for a fish basket). `map_view_mesh_builder_prop_models.gd:284,294`
call them once each. The only variation in the whole fleet is a faction pennant colour on the
merchant hull. `docs/reports/reval_harbour_1343_research.md` already asks for "six small working
boats" at Kalamaja plus four roadstead cogs - so one fishing design has to cover six visible hulls.

## Deliverable

1. A GLB fleet under `assets/vehicles/vessels/`, built through the existing Blender pipeline, each
   hull with albedo + normal + roughness, built to the CO-05 dossier dimensions and cited by entry:
   - `cog_hanseatic` - cargo cog, 2 wear variants
   - `fishing_boat_small`, `fishing_boat_large` - inshore clinker, 3 wear/load variants each
   - `rowing_boat_open` - pier and ferry craft, 2 variants
   - `lighter_lodja` - coastal/river lighter
   - `strait_craft_saaremaa` - the Saaremaa strait boat
2. **Separated, named sub-nodes** on every rigged hull so CO-07 can drive them:
   `Hull`, `Mast`, `Yard`, `Sail`, `Sheet`, `Brace`, `Halyard`, `Shroud*`, `Oar*`, `Rudder`, `Tiller`,
   `MooringLine*`, `Pennant`. Sail mesh carries enough spanwise segments (>= 8x6 grid) to billow.
3. A variant selector: `map_view_mesh_builder_prop_models.gd` picks hull design, wear variant, cargo
   dressing and moored-vs-hauled pose deterministically from `(map_seed, prop_id)`, so the six
   Kalamaja boats differ and the same map always looks the same.
4. `BoatFloat3D` hull extents (`FISHING_HULL_*` constants near `boat_float_3d.gd:35`) generalised to
   per-design extents read from the asset so heave/pitch/roll sampling matches each real hull instead
   of one hard-coded footprint. Hauled-up hulls must not float.
5. The two primitive builders are **deleted**, and their call sites replaced. Keep the prop IDs.
6. `assets/SOURCES.csv` rows for every mesh and texture, with the CO-05 dossier entry in `edits`.

## Allowed files

- `assets/vehicles/vessels/**` (new)
- `assets/SOURCES.csv`
- `tools/build_vessels.py` (new Blender build script)
- `scripts/map/view3d/map_view_mesh_builder_prop_models.gd`
- `scripts/map/view3d/map_view_fishing_boat_builder.gd`,
  `scripts/map/view3d/map_view_merchant_boat_builder.gd` (+ `.uid`) - deletion
- `scripts/map/view3d/boat_float_3d.gd` (per-design hull extents only)
- `tests/godot/test_vessel_fleet.gd` (new), `tests/godot/test_boat_float_3d.gd`
- `tools/capture_co06_vessel_fleet.gd` (new)
- `docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`, `docs/reports/co06_vessel_fleet.md`,
  `docs/reports/images/co06_*.png`, `TODO.md`

## Constraints and non-goals

- Asset freeze P0-040: exactly the files above.
- Prop IDs, map files, transitions and anchors are untouched. A boat prop keeps its ID and its cell.
- No boarding, sailing, crewing or vessel gameplay. These are props.
  `docs/reports/reval_harbour_1343_research.md` decision 4 ("do not invent a boarding mechanic") holds.
- No rig or oar **animation** here. CO-06 ships the rigged asset; CO-07 moves it.
- Every hull proportion traces to a CO-05 entry. If the dossier lacks a number, CO-05 is extended
  first; do not invent it in the mesh.
- Respect the storage policy and the character/prop triangle budgets. Roadstead cogs are seen at
  distance and must ship an LOD.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_vessel_fleet,test_boat_float_3d
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_map_blueprints.gd
python3 tools/validate_asset_sources.py && python3 tools/verify_asset_lint.py && python3 tools/verify_storage_hygiene.py
python3 tools/verify_map_audit.py
python3 tools/generate_active_docs_report.py --check
```

- `test_vessel_fleet.gd` asserts: every design loads; every rigged hull exposes the full named
  sub-node set; sail mesh has >= 8x6 segments; variant selection is deterministic per
  `(map_seed, prop_id)` and produces >= 3 distinct hull appearances among the six Kalamaja fishing
  boats; hauled-up hulls are not registered with `BoatFloat3D`; no reference to the deleted builders
  remains anywhere in `scripts/`.
- `test_boat_float_3d.gd` extended: each design's hull extents come from the asset, and hulls of
  different length pitch by different amounts on the same wave.
- `tools/capture_co06_vessel_fleet.gd` through `tools/godot_render.sh`: a fleet line-up plate at fixed
  framing, a Kalamaja beach plate showing all six boats in one shot (proving variety), and a roadstead
  plate, clear noon and storm, before and after, Compatibility and Metal.

## Doc updates

`docs/ASSET_INVENTORY.md`, `docs/ART_BIBLE.md`, `docs/reports/co06_vessel_fleet.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-953 | deps: R-952 | deliverable: authored GLB vessel fleet (cog, two inshore fishing sizes, rowing boat, lodja lighter, Saaremaa strait craft) with wear/load variants, named rig sub-nodes, segmented sail meshes, deterministic per-prop variant selection, per-design BoatFloat3D hull extents and LODs, deleting both primitive boat builders | allowed files: per docs/tasks/coast/CO-06_vessel_asset_fleet.md | verify: `--filter=test_vessel_fleet,test_boat_float_3d`; blueprint validate; asset sources/lint/storage; map audit; active docs; >= 3 distinct appearances among the six Kalamaja boats; no reference to the deleted builders remains; fleet line-up, six-boat beach and roadstead plates clear/storm before/after on Compatibility and Metal
```
