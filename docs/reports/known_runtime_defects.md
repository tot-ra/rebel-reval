# Known runtime defects (P0-019)

Severity scale: `critical` (blocks core play), `high` (major feature broken; workaround may exist), `medium`, `low`.

Recorded during **P0-017** seed and expanded under **P0-019** on 2026-07-16.

## Test scope (P0-019)

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

**Result:** One pre-existing `high` headless defect (`DEF-001`) reconfirmed. Three additional `high` defects found in district navigation and `reval_center` loading (`DEF-003` through `DEF-005`). No new `critical` defects observed. Default Start flow (`main_menu` -> `reval_east`) and headless loads of `reval_east`, `reval_north`, and `forge` pass without parser or missing-resource errors.

Commands reference: [`docs/SETUP.md`](../SETUP.md), baseline: [`startup_baseline.md`](./startup_baseline.md).

---

## DEF-001 | high | `godot --headless --check-only` hangs

| Field | Detail |
|-------|--------|
| Severity | high |
| First seen | P0-017 baseline (Godot 4.4.1 and 4.7.1) |
| Reconfirmed | P0-019 (Godot 4.7.1, 2026-07-16) |
| Affects | Headless CI parser check documented in `docs/SETUP.md` |

### Reproduction

```bash
git clone <repository-url> rebel-reval-clean
cd rebel-reval-clean
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --quit   # optional: ensure import complete
/Applications/Godot.app/Contents/MacOS/Godot --headless --check-only
```

Wait at least 15 seconds.

### Expected

Process exits within a few seconds with code `0` and no script parse errors.

### Actual

Process prints the engine banner to stdout and does not exit (observed >15s; terminated by watchdog). No stderr output.

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
| Affects | Headless `--quit-after` shutdown for main menu and `reval_east` |

### Reproduction

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 5
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 5 scenes/reval_east/reval_east.tscn
```

### Expected

Clean shutdown with no leak warnings.

### Actual

Stderr reports `ObjectDB instances leaked at exit` and `resources still in use at exit`. Exit code remains `0`. Scenes load successfully.

### Workaround

None required for local smoke tests. Investigate with `--verbose` if leaks grow or affect long-running sessions.

---

## DEF-003 | resolved | `reval_south` scene added with dev-traversal wiring

| Field | Detail |
|-------|--------|
| Severity | resolved (was high) |
| Resolved | 2026-07-20 |
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

`DoorNavigator` maps `reval_south` to `res://scenes/reval_south/reval_south.tscn`, but that file is not in the repository.

### Expected

Scene changes to the south district; player spawns at the matching `Doors/door_<tag>` marker.

### Actual

Headless direct load:

```text
ERROR: Cannot open file 'res://scenes/reval_south/reval_south.tscn'.
ERROR: Failed loading resource: res://scenes/reval_south/reval_south.tscn.
```

At runtime, `load()` returns `null` and `change_scene_to_packed(null)` logs:

```text
ERROR: Can't change to a null scene. Use unload_current_scene() if you wish to unload it.
```

The player remains in the current scene after the door sound finishes.

### Workaround

Avoid south-bound doors. Use east/north/center/forge doors that reference existing scenes. Remove or stub `reval_south` in `DoorNavigator` until a scene lands (**P0-022** / slice district work).

### Notes

Referenced by `scripts/global/doorNavigator.gd` and doors in `scenes/reval_east/reval_east.tscn` and `scenes/reval_center/reval_center.tscn`. Out of vertical-slice scope per README, but still breaks navigation when encountered.

---

## DEF-004 | high | `revel_east` typo in door `destination_level_tag`

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

`DoorNavigator.scene_paths` only defines `reval_east`, not `revel_east`.

### Expected

Scene changes to `reval_east` at the destination door spawn.

### Actual

`DoorNavigator.go_to_scene` prints `scene does not have level tagrevel_east` to stdout and returns without changing scenes. No stderr error. Player stays in the current scene after the door sound.

### Workaround

Use other doors (for example, alternate `reval_north` doors tagged `reval_east`, or restart from main menu). Fix by renaming the tag to `reval_east` in the affected `.tscn` files (**P0-022**).

### Notes

Typo is in scene exports only; the correct scene path `res://scenes/reval_east/reval_east.tscn` exists and loads cleanly.

---

## DEF-005 | high | `reval_center` references missing `revel_walls_towers/wall-map.png`

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

### Actual

```text
ERROR: Resource file not found: res://scenes/revel_walls_towers/wall-map.png (expected type: Texture2D)
ERROR: res://scenes/reval_center/reval_center.tscn:74 - Parse Error: [ext_resource] referenced non-existent resource at: res://scenes/revel_walls_towers/wall-map.png.
```

The texture exists at `res://scenes/reval_walls_towers/wall-map.png` (typo: `revel_` vs `reval_`). Process still exits `0`, but the tile map layer loses its texture.

### Workaround

Stay in `reval_east` / `reval_north` for smoke testing. Fix the `ext_resource` path in `scenes/reval_center/reval_center.tscn` line 4 to `res://scenes/reval_walls_towers/wall-map.png`.

### Notes

Only scene in the P0-019 sweep that emitted missing-resource errors. Other `reval_center` assets (music under `music/revel_east/`, `revel-map.jpg`) resolve correctly.

---

## Defects considered but not elevated

| Observation | Severity | Reason |
|-------------|----------|--------|
| Headless macOS export (`godot --headless --export-release "rr"`) | n/a (environment) | Fails on missing export templates and ETC2 ASTC project setting on the test host; not a player-runtime defect in the vertical slice. |
| Godot 4.4.1 missing `run` animation errors in `reval_east` | n/a (resolved) | Did not reproduce under Godot 4.7.1 (see `startup_baseline.md`). |
| Per-frame player velocity `print` in `scripts/player.gd` | tracked as **P0-020** | Debug noise, not a blocking runtime failure. |
