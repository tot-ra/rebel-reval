# Map playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Map role.

## Role-specific lessons
- For SubViewport evidence captures, use the Metal rendering driver and verify the saved PNG header/dimensions; headless dummy rendering may not expose a readable texture.
- In Godot 4.7 evidence helpers, conditional inference from `definition.map_id` can become a `Variant` warning treated as an error; explicitly cast map IDs to `String` when building capture filenames.
- Headless/dummy rendering cannot read a SubViewport texture; use Metal for PNG evidence.
- RRMap `stroke` thickness grows from the start point in +x/+y, it is not centred on the polyline. Author river and lane strokes from their top-left edge or the compiler rejects the segment as out of bounds.
- A new `view_landmark` kind needs three registrations, not one: `MapDefinition.VIEW_LANDMARK_KINDS`, the `_compile_landmark` field copy in `map_blueprint_compiler_build.gd`, and `LANDMARK_OVERRIDE_KEYS` for any new typed option. The parser token allowlist is separate again.
- An outdoor district map should express buildings as roofed `house` records; `kind=interior_wall` produces roofless panels and a large "building" made of them renders as a stockade, not an institution.
- Reserve roofless `kind=wall` records for burnt-out shells and boundary walls, where the missing roof is the point.
- When a close-up capture needs a different framing, re-aim the shipped camera along its own `basis.z` instead of offsetting `position` in world XZ; an orthographic isometric camera offset that way slides off the map into sky.
- RRMap `stroke` polylines are strictly orthogonal; represent angled historic street approaches as stepped axis-aligned segments before running the compiler.
- On macOS, `godot` is often not on `PATH`; use `/Applications/Godot.app/Contents/MacOS/Godot` or set `GODOT_BIN` before running headless tests or map pipeline scripts.
- When a TODO allowlist names only `map_blueprint_compiler.gd` for a new typed style key, also update `map_blueprint_compiler_build.gd` (field copy) and `map_blueprint_compiler_expand_geometry.gd` / expand validation, or the key parses but never reaches `MapDefinition` and rejection tests stay red.
- An NPC "standing on the smithy anvil" is usually an authored anvil-bound activity (`ap.visitor.inspect` / `ap.forge.anvil`) whose `approach_position` sits inside `forge_anvil` footprint, not a stray spawn; in prologue prefer Henning inspect over Mart (Mart stays hidden while `flag.mart_missing`).
- RRMap parser support files live under `scripts/map/rrmap/`; discover them before reading instead of inferring a flat `scripts/map/map_rrmap_*.gd` path from a class name.
- Spoken "кавальня" / "на Кавальне" in Workers District notes usually means the outdoor `courtyard_anvil` (наковальня), not a building name; confirm against `lower_town_slice.rrmap` before inventing a new landmark.
- Retiring a stable outdoor prop ID (for example `courtyard_anvil` → `courtyard_firewood`) requires regenerating `lower_town_slice.parity.json` with `tools/regenerate_lower_town_slice_parity.gd -- --write-lower-town-slice-parity-fixture` in the same change.
- ADR 0018 matched day/night calibration captures must use one Godot process per plate; batching many SubViewport MapView3D builds in one process eventually yields blank frames after the first few.
- Outdoor night crushed to black after ADR 0018 is usually ambient/fill and clean-painted night multipliers, not the 20% post-grade luminance proxy alone; raise `AMBIENT_NIGHT_ENERGY` / night terrain multipliers before breaching the proxy.
- Pass `tools/run_godot_checked.sh` a basename such as `seamless-terrain-chunks`, not an absolute `/tmp/...` path; the wrapper creates its own `${TMPDIR}/<log-name>.log` and nested path separators make a green Godot run fail during log capture.
- Prop close-up captures must zero `build_prop` world position (and add a WorldEnvironment); otherwise the kit sits at map cell coords and the SubViewport plate is a solid ambient swatch. Prefer the map definition preload over `MapAuditRegistry` when distant dirty maps can abort the run.
- New Game places the player via DoorNavigator spawn `smithy_start`, not `definition.player_spawn`. Moving only `spawn.main` leaves Kalev at the anvil; keep `transition smithy_start_spawn` on the same wake cell as `ap.sleep.wake` / bed foot.
- Godot `--headless` SubViewport closeups hit the dummy renderer (`texture_2d_get` null / `save_png` on null). Capture banner plates with a real driver instead: `/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-driver metal --script tools/capture_cloak_banner_closeup.gd`. Do not pipe the checked runner through `tail` until exit - it hides the live log while the process is still running.
- RRMap compiler expands long interior walls into stable segmented IDs such as `wall.north_forge/segment.000`; integration tests must inspect compiled records or use a prefix-aware lookup, not assume the source statement ID survives unchanged. When a focused test fails in a dirty mesh-builder worktree, inspect the saved log and separate pre-existing renderer errors from the scoped fixture.
- For visual sign-off reports, distinguish documentation studies and asset previews from gameplay-camera acceptance; when corridor assets or placements are missing, record a conditional pass and name the owning follow-up rows instead of inventing captures.
- Discover map alignment helper paths before reading them; `MapAlignmentMath` is not necessarily stored at `scripts/map/map_alignment_math.gd`.
- When one prop-kind suffix appears in both a grouped registry and `ALL_PROP_KINDS`, include the array declaration in exact edits; matching only the trailing entries is ambiguous.
- When carving a narrow commit from a dirty smithy worktree, reset `kalev_smithy.rrmap`, `kalev_smithy_domestic_life.json`, and `content/routines/kalev_smithy.json` together to a matched baseline before verifying; a HEAD map against a dirty fixture/routine fails on missing kitchen props even when the spawn patch is correct.
- Discover exact support-file paths before reading; `MapWallWalkAccess` lives under `scripts/map/view3d/`, not the flatter inferred `scripts/map/` path.
- When editing repeated spawn objects in `active_destinations.json`, include the enclosing scene context in exact replacements; a bare final-spawn object can match multiple scene registries.
- Run `map_pipeline_hardening` outside a large parallel batch with a longer timeout; its focused harness can exceed the parallel step's 90-second ceiling even when other map suites finish quickly.
- In a dirty worktree, isolate focused camera regressions from unrelated rig/runtime WIP; report the target camera test separately instead of attributing every suite failure to a spawn-only map change.
