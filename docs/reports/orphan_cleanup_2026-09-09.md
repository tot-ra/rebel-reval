# Orphan cleanup inventory (2026-09-09)

Evidence-based removal of unused menu stills, leftover Godot probes, and one orphan UID sidecar. Not a blanket legacy purge.

## Consumer checks

Tracked-text search excluded `TODO.md` and `*.import` sidecars.

| Path | Size | Consumers | Decision |
|------|------|-----------|----------|
| `scenes/menu/intro.mp4` | 9.50 MiB | none | **Keep.** Same duration (5.031 s) and resolution (1152x768) as accepted `intro.ogv`; H.264 bitrate is about 6x Theora. Needed to re-encode the menu video without a Theora generation loss. |
| `scenes/menu/intro.png` | 2.57 MiB | none (`intro.png.import` only) | **Remove** with import sidecar. Accepted still is `intro-hq.jpg` at 3072x2048 (2x PNG). PNG cannot regenerate that still. |
| `scenes/menu/intro.ogv` | 1.54 MiB | `scenes/menu/main_menu.tscn` | Keep (runtime menu video). |
| `scenes/menu/intro-hq.jpg` | 1.16 MiB | `scenes/menu/main_menu.tscn` | Keep (runtime fallback still; sprite currently hidden). |
| `scenes/menu/logo256.png` | 56 KiB | `main_menu.tscn`, `project.godot`, `export_presets.cfg`, CI | Keep. |
| `scenes/menu/logo.png` | 1.8 MiB | docs / `faction_heraldry.gd` brand note | Keep (brand reference). |
| `scenes/menu/intro.jpg` | 249 KiB | none | Keep. Different crop (1392x752), not a resize of the HQ still; left for a later stills pass. |
| `scenes/menu/logo-export.png` | 52 KiB | none | Keep. 256px variant that does not match `logo256.png` pixel-for-pixel. |

`tools/_tmp_*` and `tools/_debug_chunk_index.*` have no CI, test, or live-doc invocation. Historical reports cite other already-removed probes (`_tmp_r598_metrics.gd`, `_tmp_capture_r455_elevation.gd`).

## Removed

- `scenes/menu/intro.png`
- `scenes/menu/intro.png.import`
- `tools/_tmp_duck_aabb.gd.uid` (orphan UID; script never tracked)
- `tools/_tmp_r577_camera_probe.gd` and `.uid`
- `tools/_tmp_saaremaa_probe.gd` and `.uid`
- `tools/_tmp_capture_saaremaa.gd` and `.uid`
- `tools/_tmp_capture_monastery_east_south.gd` and `.uid`
- `tools/_debug_chunk_index.gd` and `.uid`

## Sprite / UI inspection

- P0-023 listed 28 orphan `.import` sidecars. Current index has **zero** orphan `.import` files.
- `assets/UI/character-hud/` is already absent. ADR 0017 / README keep those icons as inspiration only; do not restore them as production HUD. `character/BUILD.md` still embeds those paths as legacy prose illustrations.
- Live UI loaders still use `assets/UI/inventory/`, `assets/UI/cursors/`, `assets/UI/death/`, and `assets/UI/estonia_world_map.png`. Those sources and sidecars stay.
- `assets/player/` retains a README plus `.aseprite` / `.pxo` sources; production runtime does not load pixel-frame sheets from there.
- Music, documentation plates, valid `.uid` / `.import` pairs, and ADR 0017 design prose were not deleted.

## Guard

`tools/verify_storage_hygiene.py` now fails when:

- a tracked `tools/_tmp*` or `tools/_debug*` path remains
- a tracked `.import` or `.uid` sidecar has no matching source in the Git index

Runtime `scripts/ui/debug_overlay.gd` and `tests/godot/test_debug_*` are out of that prefix/directory scope.

## Verification

- `python3 -m unittest tests.python.test_verify_storage_hygiene tests.python.test_verify_asset_lint -v`: 31 tests, OK
- `python3 tools/verify_storage_hygiene.py`: pass
- `python3 tools/validate_asset_sources.py`: pass
- `python3 tools/verify_asset_lint.py`: pass
- Detached HEAD worktree (`a59e8d0e` plus this patch, empty `.godot/`): `godot --headless --editor --quit` pass; menu smoke `--quit-after 5` pass; `--filter=test_main_menu_load` 6/6. No `intro.png` import errors.
- Live dirty tree menu smoke also pass; character-texture UID warnings there belong to concurrent shared-rig WIP.
