# Known runtime defects (P0-019 / P0-060)

Severity scale: `critical` (blocks core play), `high` (major feature broken; workaround may exist), `medium`, `low`, `resolved`.

Recorded during **P0-017** seed and expanded under **P0-019** on 2026-07-16. Re-triaged under **P0-060** on 2026-07-20 against current `main` (transition manifest + programmatic district scenes).

## P0-060 re-triage summary (2026-07-20)

| ID | Prior | Decision | Evidence |
|----|-------|----------|----------|
| DEF-001 | high | **Retained** (high) | `godot --headless --check-only` still hangs (>12s, engine banner only) on Godot 4.7.1 |
| DEF-002 | low | **Retained** (low) | Headless quit still reports ObjectDB/resource leak lines; allowlisted in `tools/run_godot_checked.sh` |
| DEF-003 | high | **Resolved** | `scenes/reval_south/reval_south.tscn` exists; wired as inactive prototype via transition manifest |
| DEF-004 | high | **Resolved** | No `revel_east` `destination_level_tag` remains in `.tscn` files; forge/north use manifest scene ids |
| DEF-005 | high | **Resolved** | `reval_center.tscn` is a programmatic MapScene host; no `revel_walls_towers/wall-map.png` ext_resource |
| DEF-006 | low | **Retained** (low) | MultiMesh ShaderMaterial teardown ERROR still mitigated by strip-before-free helpers |

Replacing navigation system for DEF-003/004/005 era reports: hard-coded `DoorNavigator.scene_paths` and district TileMap `.tscn` door exports were superseded by `content/transitions/active_destinations.json` consumed by `scripts/global/doorNavigator.gd`, plus `MapSceneBootstrap` district hosts.

## Test scope

### Original P0-019 seed

| Field | Value |
|-------|-------|
| Host OS | macOS (darwin arm64) |
| Godot binary | `/Applications/Godot.app/Contents/MacOS/Godot` |
| Godot version | `4.7.1.stable.official.a13da4feb` |
| Repository HEAD | `489b63a3669d48afed6e592b7cd2a37cb03b075e` |
| Import | `godot --headless --editor --quit` (exit `0`) |
| Scene sweep | All `36` scenes under `scenes/**/*.tscn` with `--quit-after 3` |
| Playable smoke | `main_menu`, `reval_east`, `reval_north`, `forge`, `reval_center`, `harbor`, `intro` |
| Parser check | `godot --headless --check-only` (15s watchdog) |
| Door tags | Manual review of `destination_level_tag` in district `.tscn` files and `scripts/global/doorNavigator.gd` |
| Transition simulation | Headless GDScript repro of `DoorNavigator.go_to_scene` failure modes |

### P0-060 reconfirm

| Field | Value |
|-------|-------|
| Host OS | macOS (darwin arm64) |
| Godot binary | `/Applications/Godot.app/Contents/MacOS/Godot` |
| Godot version | `4.7.1.stable.official.a13da4feb` |
| Checks | `--check-only` hang (12s); `rg` for `revel_east` / wall-map refs; forge `--quit-after 3` smoke; south scene path existence |

Commands reference: [`docs/SETUP.md`](../SETUP.md), baseline: [`startup_baseline.md`](./startup_baseline.md).

---

## DEF-001 | high | `godot --headless --check-only` hangs

| Field | Detail |
|-------|--------|
| Severity | high |
| First seen | P0-017 baseline (Godot 4.4.1 and 4.7.1) |
| Reconfirmed | P0-019 (2026-07-16); **P0-060 (2026-07-20)** |
| Affects | Headless CI parser check documented in `docs/SETUP.md` |

### Reproduction

```bash
git clone <repository-url> rebel-reval-clean
cd rebel-reval-clean
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --quit   # optional: ensure import complete
/Applications/Godot.app/Contents/MacOS/Godot --headless --check-only
```

Wait at least 12 seconds.

### Expected

Process exits within a few seconds with code `0` and no script parse errors.

### Actual

Process prints the engine banner to stdout and does not exit (observed >12s on 2026-07-20; terminated by watchdog). No stderr output.

### Workaround

Use playable-room smoke until fixed:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 5 scenes/reval_east/reval_east.tscn
```

Exit `0` with no parser or missing-resource errors under Godot 4.7.1.

### Notes

Does not block editor F5 play or headless scene load. Blocks relying on `--check-only` alone for CI until root cause is found.

---

## DEF-002 | low | Headless exit resource leaks

| Field | Detail |
|-------|--------|
| Severity | low |
| First seen | P0-017 baseline (Godot 4.7.1) |
| Reconfirmed | **P0-060 (2026-07-20)** via forge `--quit-after` smoke |
| Affects | Headless `--quit-after` shutdown for main menu, forge, and `reval_east` |

### Reproduction

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 5
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 5 scenes/reval_east/reval_east.tscn
```

### Expected

Clean shutdown with no leak warnings.

### Actual

Stderr reports `ObjectDB instances leaked at exit`, `resources still in use at exit`, and on larger headless suite runs additional shutdown-only lines such as `RID allocations of type '...' were leaked at exit` and `Pages in use exist at exit in PagedAllocator: ...`. Exit code remains `0`. Scenes load successfully.

### Workaround

None required for local smoke tests. `tools/run_godot_checked.sh` allowlists only these shutdown-only DEF-002 lines so they do not fail CI; investigate with `--verbose` if leaks grow or affect long-running sessions.

---

## DEF-006 | low | Headless MultiMesh ShaderMaterial teardown ERROR

| Field | Detail |
|-------|--------|
| Severity | low |
| First seen | P0-062 (Godot 4.7.1, 2026-07-20) |
| Affects | Headless tests that free `MapViewRuntime` / `MapView3D` trees containing `MultiMeshInstance3D` nodes with `ShaderMaterial` and instance colors |

### Reproduction

Build a `MapViewRuntime` (or any map view with grass/canopy MultiMeshes), add it to the scene tree, then `free()` the host without clearing materials first.

### Expected

Quiet teardown under the headless dummy `RenderingServer`.

### Actual

`ERROR: Parameter "material" is null` from `material_get_instance_shader_parameters` while children leave the tree. Godot propagates exit to children before the parent can clear overrides, so a parent `_exit_tree` strip is too late.

### Workaround / mitigation

Call `MapView3D._strip_geometry_materials(root)` while the tree is still live, then free. Camera-mode and click-input tests use `_free_map_scene` / purge helpers for this. Orphan `MapView3D.create()` fixtures that are never entered into the tree do not hit the path.

### Notes

Does not affect editor play or exported builds with a real renderer. Keep the strip helper rather than allowlisting the ERROR so unexpected material failures stay visible.

---

## DEF-003 | resolved | `reval_south` scene added with dev-traversal wiring

| Field | Detail |
|-------|--------|
| Severity | resolved (was high) |
| Resolved | 2026-07-20 |
| Replacing system | `content/transitions/active_destinations.json` + `scenes/reval_south/reval_south.tscn` (inactive prototype) |
| Affects | South district transitions from `reval_east` (Karja Gate) and `reval_center` |

`reval_south` now ships as an `active=false` developer prototype at `scenes/reval_south/reval_south.tscn`, wired reciprocally from `karja_road_boundary` on the Lower Town slice and `to_reval_south` on the civic centre.

---

## DEF-003 (archived text) | high | `reval_south` scene missing but registered in `DoorNavigator`

| Field | Detail |
|-------|--------|
| Severity | high |
| First seen | P0-019 (Godot 4.7.1) |
| Affects | South district door transitions from `reval_east` and `reval_center` |

### Reproduction

**Headless load check:**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 3 scenes/reval_south/reval_south.tscn
```

**In editor (player-visible):**

1. Run the project (F5) and reach `reval_east` (default Start flow).
2. Walk the player into a door whose `destination_level_tag` is `reval_south` (south edge doors in `scenes/reval_east/reval_east.tscn`).
3. Alternatively, reach `reval_center` and use its south door (`scenes/reval_center/reval_center.tscn`).

`DoorNavigator` mapped `reval_south` to `res://scenes/reval_south/reval_south.tscn`, but that file was not in the repository at the time of the report.

### Expected

Scene changes to the south district; player spawns at the matching spawn marker.

### Actual (historical)

Headless direct load failed with missing scene resource errors; runtime `change_scene_to_packed(null)` left the player in place.

### Resolution

South quarter prototype scene landed; transitions use the active destinations manifest. See resolved entry above.

---

## DEF-004 | resolved | `revel_east` typo retired with manifest transitions

| Field | Detail |
|-------|--------|
| Severity | resolved (was high) |
| First seen | P0-019 (Godot 4.7.1) |
| Resolved | P0-060 re-triage (2026-07-20) |
| Replacing system | `content/transitions/active_destinations.json` scene ids (`reval_east`, `forge`, ...) via `DoorNavigator.go_to_scene` |
| Affects | Historical forge exit / north-return doors that exported `destination_level_tag = "revel_east"` |

### Historical reproduction (no longer present)

```bash
grep -n 'destination_level_tag = "revel_east"' scenes/reval_east/forge/forge.tscn scenes/reval_north/reval_north.tscn
```

### P0-060 reconfirm

```bash
rg -n 'revel_east' scenes --glob '*.tscn'
# no matches
```

Forge and north district hosts no longer embed the typo tag. Transitions resolve through the manifest.

---

## DEF-004 (archived text) | high | `revel_east` typo in door `destination_level_tag`

| Field | Detail |
|-------|--------|
| Severity | high |
| First seen | P0-019 (Godot 4.7.1) |
| Affects | Forge exit door and one `reval_north` door back to east |

### Reproduction

**In editor (player-visible):**

1. From `reval_east`, enter the forge via the door tagged `forge` (works).
2. In `scenes/reval_east/forge/forge.tscn`, walk into `Doors/door_main` (exports `destination_level_tag = "revel_east"`).
3. Or from `reval_north`, walk into `Doors/door_center2` (`destination_level_tag = "revel_east"`).

**Headless tag check:**

```bash
grep -n 'destination_level_tag = "revel_east"' scenes/reval_east/forge/forge.tscn scenes/reval_north/reval_north.tscn
```

`DoorNavigator.scene_paths` only defined `reval_east`, not `revel_east`.

### Expected

Scene changes to `reval_east` at the destination door spawn.

### Actual (historical)

`DoorNavigator.go_to_scene` printed a missing-level-tag message and returned without changing scenes.

### Resolution

Typo exports removed; manifest-backed scene ids replaced district door-tag routing. See resolved entry above.

---

## DEF-005 | resolved | `reval_center` missing wall-map texture retired with programmatic host

| Field | Detail |
|-------|--------|
| Severity | resolved (was high) |
| First seen | P0-019 (Godot 4.7.1) |
| Resolved | P0-060 re-triage (2026-07-20) |
| Replacing system | Programmatic `MapSceneBootstrap` / market-civic quarter definition driving `scenes/reval_center/reval_center.tscn` (no TileMap wall-map ext_resource) |
| Affects | Historical TileMap `reval_center` that referenced `res://scenes/revel_walls_towers/wall-map.png` |

### Historical reproduction

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 5 scenes/reval_center/reval_center.tscn
```

Expected missing-resource errors for the typo path `revel_walls_towers` while the file lived at `reval_walls_towers`.

### P0-060 reconfirm

```bash
rg -n 'wall-map|revel_walls' scenes/reval_center/
# no matches
```

Current `reval_center.tscn` is a slim host (`reval_center.gd` + player); ground art comes from the compiled map view, not the legacy wall-map texture.

---

## DEF-005 (archived text) | high | `reval_center` references missing `revel_walls_towers/wall-map.png`

| Field | Detail |
|-------|--------|
| Severity | high |
| First seen | P0-019 (Godot 4.7.1) |
| Affects | `reval_center` district tile map texture (playable prototype area) |

### Reproduction

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 5 scenes/reval_center/reval_center.tscn
```

Or run the project and transition to `reval_center` via any east/north door tagged `reval_center`.

### Expected

`reval_center` loads with the wall-map ground texture applied. No missing-resource errors.

### Actual (historical)

```text
ERROR: Resource file not found: res://scenes/revel_walls_towers/wall-map.png (expected type: Texture2D)
ERROR: res://scenes/reval_center/reval_center.tscn:74 - Parse Error: [ext_resource] referenced non-existent resource at: res://scenes/revel_walls_towers/wall-map.png.
```

The texture existed at `res://scenes/reval_walls_towers/wall-map.png` (typo: `revel_` vs `reval_`). Process still exited `0`, but the tile map layer lost its texture.

### Resolution

Center district converted to a programmatic map host without that ext_resource. See resolved entry above.

---

## D-004a packaged release triage (2026-07-20)

| Field | Detail |
|-------|--------|
| Scope | Release-build-only defects during packaged move-talk-pickup that do not reproduce under editor / `godot --path .` |
| Evidence | [`d004a_release_only_triage.md`](./d004a_release_only_triage.md) |
| Verdict | **No release-only gameplay defects remain** |
| Tooling note | Pre-fix `tools/verify_packaged_demo.sh` passed `--path` to the release binary; official templates abort (`compiled without support for path overrides`). Fixed to launch with `--quit-after` only. |
| Shared with editor | Packaged `--quit-after` still prints DEF-002 ObjectDB / resource leak lines |

No new DEF IDs were opened for D-004a. Optional follow-ups: **D-004b** (human video), **D-004c** (in-binary packaged walkthrough without editor `--path`).

---

## Defects considered but not elevated

| Observation | Severity | Reason |
|-------------|----------|--------|
| Headless macOS export (`godot --headless --export-release "rr"`) | n/a (environment) | Historically failed on missing export templates on some hosts; CI macOS export smoke now covers the preset. |
| Godot 4.4.1 missing `run` animation errors in `reval_east` | n/a (resolved) | Did not reproduce under Godot 4.7.1 (see `startup_baseline.md`). |
| Per-frame player velocity `print` in `scripts/player.gd` | tracked as **P0-020** | Debug noise, not a blocking runtime failure. |
| Release template rejects CLI `--path` / scene args | n/a (template limit) | Expected for official macOS release exports; players launch the `.app` without overrides. Documented under D-004a; verification script must not rely on path overrides. |
