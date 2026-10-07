# UF-15: Hinterland maps and second world layout
Board row: **R-1133**. Priority: high. Depends on: **R-1129 (ADR 0027 accepted), R-980, R-1213, R-1215, R-1216, R-1217**, plus the UF-08 seam-continuity gate (shipped as `tools/verify_seam_continuity.gd`, follow-up **R-1166**) and relief (**R-976** pack id; no board row).

## Claim gate

[ADR 0027](../../adr/0027-reval-hinterland-streaming-group.md) section 4 ends with: "UF-15 must not be claimed until the Producer names a Dev owner for bridge and layout-tool support." That support is **R-1217**. This row stays unclaimable until a Dev owner is named there.

## Prerequisite rows

ADR 0027 section 3 names three Reval-side endpoints that do not exist in `content/maps/` today, and one piece of tool support. Each is a separate board row so UF-15 does not have to edit a `reval_outdoor` member and invent a second group in the same change. Every row below authors an **aperture only**: geometry, anchors and audit rows, with no transition record, no membership change and no streaming-flag change. UF-15 adds the reciprocal transitions when the connector maps exist.

| Row | Change | Why it is separate |
|---|---|---|
| **R-1213** (UF-15a, `role:map`) | Harju Gate aperture on the `south_quarter` south curtain: throat through the stepped curtain in the x=160..178 corridor, `street.harju` stroke, causeway over `terrain south_wall.ditch.west` (156,90 72x6), `landmark harju_gate_arch`, `anchor harju_gate_threshold` / `harju_approach` | No map has a Harju Gate. The south curtain carries only the Karja Gate and the travel exit `to_world_sacred_grove`. Edits a `reval_outdoor` member, so it must pass the full outdoor gate set on its own |
| **R-1215** (UF-15b, `role:map`) | Landward aperture on `reval_harbor_east`: cleared track from `quay_plaza` south through the woodland belt, `anchor kalamaja_landward_threshold` / `kalamaja_landward_approach` | `reval_harbor_east` has exactly one transition, `to_harbor_north` (140,47 4x8, east edge). Depends on CO-04 / **R-951**, which owns the Kalamaja shore level ladder |
| **R-1216** (UF-15c, `role:map`) | Viru-road junction aperture on `world.sojamae`: dry causeway across `wet_north` on the chosen north edge, `anchor sojamae_viru_threshold` / `sojamae_viru_approach` | `world.sojamae` connects only to `world.harju` and `world.paide` and has no Viru-road junction. Both its transitions stay `alignment=travel` |
| **R-1217** (UF-15d, `role:dev`) | Named group registry, `--group=<id>` on `tools/build_world_layout.gd`, allowlisted inter-group gate bridges with a deterministic integer transform, fail-closed validator rules from ADR 0027 section 5 | `scripts/map/map_world_layout.gd` hardcodes one group (`DEFAULT_WORLD_GROUP_ID`, `REVAL_OUTDOOR_MANIFEST_PATH`, `REVAL_OUTDOOR_MEMBERS`) and `tools/build_world_layout.gd` takes no group argument. `tools/verify_world_layout.py` already marks the second table as planned. ADR 0027 requires a named Dev owner |

Dependency-safe order: **R-1217** and **R-1213** can start immediately (both depend only on accepted ADR 0027; R-1213 also waits on **R-1166** so it does not land on top of graced seam violations). **R-1215** waits on **R-951**. **R-1216** can start immediately. **R-1133** starts only when all four are done.

## Gates every one of these changes must pass

```bash
godot --headless --path . --script tools/validate_map_blueprints.gd
godot --headless --path . --script tools/build_world_layout.gd -- --check
python3 tools/verify_world_layout.py
python3 tools/verify_map_audit.py
godot --headless --path . --script tools/verify_seam_continuity.gd
```

`verify_seam_continuity.gd` is the UF-08 gate and is a Godot script, not Python. It must pass with **no new `grace` rows** in `docs/data/seam_continuity_budget.json`; a grace row added to get green is a failed change. For rows that edit a `reval_outdoor` member (R-1213, R-1215) the layout manifest fingerprint changes because the member source sha changes, so `content/world/reval_outdoor_layout.json` is rebuilt in the same commit. For R-1216 and R-1217 the checked-in `reval_outdoor` manifest must be **byte-identical** afterwards. The rest of the AGENTS.md map pre-commit gate (`verify_map_activation.py`, `verify_map_conversion_plan.py`, `run_godot_tests.gd`, `generate_active_docs_report.py --check`, `git diff --check`) applies unchanged.

## Finding to carry into this row

`world.harju road_to_sojamae` sits at 27,0 on its north edge; `world.sojamae road_to_harju` sits at 0,24 on its west edge. As `alignment=travel` transitions that is legal. The moment both maps join `reval_hinterland` the pair becomes an in-group seam and fails `MAP_WORLD_SEAM_SIDES_NOT_OPPOSITE`. One of the two must move, with its spawn offsets and anchors, inside UF-15. R-1216 only writes the finding into both rrmap headers so it is not discovered late.

## Player-facing goal

Leaving the Viru or Coastal Gate, the player can walk along connected hinterland routes toward Kalamaja, Pirita and Harju without a loading screen, while shore and inland terrain visibly rise and fall.

## Why this is needed

`docs/SEAMLESS_STREAMING_PLAN.md` currently defines one `reval_outdoor` group with 10 streamed maps among 29 total maps; `content/world/reval_outdoor_layout.json` is its existing manifest. The requested connective map sources are not named concretely until ADR 0027, and the current map collection already has `viru_gate_foreland.rrmap`, `world_harju.rrmap`, and `world_sojamae.rrmap`, so distinguish genuinely new connective maps from existing travel maps rather than duplicating IDs or converting distant destinations. The coast ladder dependency belongs to CO-04 (R-951): `docs/tasks/coast/CO-04_coastal_elevation_levels.md` owns Kalamaja shore levels for `reval_harbor_east` (and the companion coast scope); UF-15 must consume that work or obtain explicit agreement. The complaint that near-sea maps are flat and houses too close to beach is CO-04's, not this row's. UF-15 owns only connecting maps and the second world layout.

## Deliverable

Author the five maps named in ADR 0027 section 3 - `kalamaja_hinterland`, `viru_approach_road`, `pirita_road`, `harju_approach_road`, `sojamae_approach_road` - as MapBlueprint blueprints and RRMap sources, explicitly register their factories in `scripts/map/map_blueprint_registry.gd`, add required anchors and reciprocal physical seams onto the apertures authored by R-1213 (Harju Gate), R-1215 (`reval_harbor_east` landward track) and R-1216 (`world.sojamae` Viru-road mouth), add the five inter-group gate-bridge rows to the R-1217 allowlist, and build `content/world/reval_hinterland_layout.json` with `tools/build_world_layout.gd -- --group=reval_hinterland`. Move `world.harju` and `world.sojamae` from travel to `reval_hinterland` membership here, which includes making `road_to_harju` / `road_to_sojamae` opposite-sided and width-compatible. Use UF-03 `extramural road` class. Keep dwellings off foreshore by consuming the CO-04 four-level foreshore/berm/dune/terrace ladder after CO-04 lands, or by explicit agreement with its owner. Preserve distinct travel beats for distant `world.*` destinations.

## Allowed files

- `content/maps/*.rrmap` (new connective maps only)
- `content/maps/south_quarter.rrmap`, `content/maps/reval_harbor_east.rrmap`, `content/maps/world_sojamae.rrmap`, `content/maps/world_harju.rrmap` - strictly to add the reciprocal transition records onto the existing apertures, not to re-author their geometry
- `scripts/map/definitions/prototypes/**`
- `scripts/map/map_blueprint_registry.gd`
- `scripts/map/map_catalog.gd`
- `scripts/map/map_audit_registry.gd`
- `scripts/map/map_world_layout.gd` (group membership rows and bridge-allowlist rows only; the registry itself is R-1217)
- `content/map_audit_manifest.json`
- `content/world/reval_hinterland_layout.json`
- `content/world/reval_outdoor_layout.json` (rebuilt output)
- `content/transitions/active_destinations.json`
- `docs/MAP_CONVERSION_PLAN.md`
- `docs/reports/scene_inventory.md`
- `tests/godot/test_hinterland_maps.gd`
- `docs/SEAMLESS_STREAMING_PLAN.md`
- `TODO.md`

## Constraints and non-goals

All new maps stay `active=false`; activation belongs to their own gate task. No giant MapDefinition dictionary factories, no filesystem discovery, and only blueprint primitives/reviewed prefabs. Register every blueprint explicitly. Never convert a distant `world.*` travel destination into a seam. Streaming flags retain ADR-0027 defaults. Depend on CO-04 for Kalamaja shore level ladder; do not assume UF-15 owns it. Preserve stable IDs, keep generated nodes disposable and diagnostics stable, and do not evade bounds/route diagnostics. Use `--headless` for all Godot commands.

## Verification

- `godot --headless --path . --script tools/validate_map_blueprints.gd`
- `godot --headless --path . --script tools/build_world_layout.gd -- --check` and `-- --group=reval_hinterland --check`; `python3 tools/verify_world_layout.py` for both groups. Second-group support is R-1217 and must be done before this row is claimed.
- `godot --headless --path . --script tools/verify_seam_continuity.gd`
- `python3 tools/verify_map_audit.py`, `python3 tools/verify_map_activation.py`, `python3 tools/verify_map_conversion_plan.py`
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_hinterland_maps`
- Headless walk from Lower Town through a gate seam to a hinterland anchor succeeds on compiled height field.
- `tools/run_map_pipeline_ci.sh benchmark-smoke` meets resident-group frame budget.
- `tools/godot_render.sh` plates show dwellings above waterline on graded shore.

## Doc updates

Update `docs/SEAMLESS_STREAMING_PLAN.md`, map audit/conversion inventory and tests to include the second group and exact connective maps established in accepted ADR 0027. The ADR 0027 maintainer decision and CO-04 ownership/dependency must be explicit before this row begins implementation.

## Board line (legacy TODO.md form)

The project task board is the sole work queue; this line is kept only as the row summary.

- [ ] R-1133 | deps: R-1129, R-980, R-1213, R-1215, R-1216, R-1217 | deliverable: registered connective hinterland blueprints, reciprocal seams onto the three authored apertures, and the second world layout, consuming CO-04 shore ladder | verify: headless blueprint/two-group layout/seam/audit/activation/conversion checks, cross-gate walk, benchmark and graded-shore plates
