# Shipped resource manifest audit (P0-202)

Date: 2026-09-09
Task: inventory actual `rr` / `act1` PCK contents, then exclude developer-only trees from release exports.

Parser: `tools/pck_inventory.py` (Godot 4.7 pack v4). Membership: `tools/verify_shipped_resources.py`. Contract: `docs/data/shipped_resource_manifest.json`.

Do not infer packed membership or byte savings from source directories. Compiled audio and meshes live under `.godot/imported/` (`.mp3str`, `.scn`, `.ctex`), not the original `music/*.mp3` / `assets/*.glb` paths.

## Do not overwrite the frozen Act 1 package

`build/act1/rr.dmg` remains the P4-013 / P4-044 bind (`docs/data/act1_release_manifest.json`, sha `ea3cf414...eafbdc`, 1,143,742,554 bytes). New minimized act1 exports go to a side path such as `build/inventory/act1-after.pck`. This task does not rebind that SHA.

## Historical July 25 all-resources PCK

Source: `build/Reval Rebel.app/Contents/Resources/Reval Rebel.pck` (pack v4, Godot 4.7.1).

| Metric | Value |
|--------|------:|
| Files | 2800 |
| Packed bytes | 765,205,985 |
| Imported `.mp3str` | 185 files / 634,422,951 |

Developer trees that were actually packed:

| Prefix | Files | Packed bytes |
|--------|------:|-------------:|
| `res://tests/` | 340 | 897,514 |
| `res://tools/` | 80 | 123,434 |
| `res://generated/` (sidecars) | 56 | 17,546 |
| `res://addons/` | 8 | 34,671 |
| `res://build/` | 17 | 1,544,866 |
| `res://docs/reports/` | 122 | 34,592 |
| `res://scenes/tests/` | 13 | 29,643 |

`LICENSE` was absent. `CREDITS.md` was present.

Imported Hunyuan / Blender rebuild blobs that this cut forbids:

| Imported blob | Packed bytes |
|---------------|-------------:|
| `cat_hunyuan3d_local.glb` `.scn` | 21,408,443 |
| `forge_cat_hunyuan3d_v1.glb` `.scn` | 4,714,221 |
| `forge_cat_reference_source.blend` `.scn` | 2,168,026 |

Those three blobs alone are about 28.3 MiB. They are not a fair delta against the current-tree packs below, because `generated/.gdignore` already hid `generated/` from both current exports. The July pack is the last on-disk all-resources artifact that still included them.

## Same-worktree before / after (2026-09-09)

Both packs used the current import cache. The before pack used empty `exclude_filter` (still `export_filter=all_resources`). The after pack used the release exclude/include strings now in `export_presets.cfg`. `generated/.gdignore` was already present, so this delta is the exclude_filter cut, not the Hunyuan blob cut.

| Pack | Files | Packed bytes |
|------|------:|-------------:|
| `build/inventory/rr-before-current.pck` | 6891 | 923,510,884 |
| `build/inventory/rr-after.pck` | 5670 | 878,530,075 |
| Delta | -1221 | -44,980,809 (~42.9 MiB) |

Imported soundtrack audio is unchanged: **197** `.mp3str` files / **706,952,999** bytes in both current packs. Optional playlist selection remains P0-180.

After-pack membership (release exclude):

| Tree | After count |
|------|------------:|
| `res://tests/` | 0 |
| `res://tools/` | 0 |
| `res://generated/` | 0 |
| `res://addons/` | 0 |
| `res://build/` | 0 |
| `res://docs/reports/` | 0 |
| `res://scenes/debug/` | 0 |
| `res://scenes/tests/` | 0 |
| `res://music/` sidecars | 131 |
| `res://characters/` | 171 |
| `res://character/` (inspiration excluded) | 10 (was 18) |
| `res://content/` | 310 |
| `res://assets/characters/cat/` | 19 |
| `res://LICENSE` | 1 |
| `res://CREDITS.md` | 1 |

`python3 tools/verify_shipped_resources.py --pck build/inventory/rr-after.pck --preset rr` passes.

`rr` and `act1` share the same include/exclude strings. `act1` membership is the same resource set; do not export over `build/act1/rr.dmg` to prove it.

## Release vs diagnostic presets

Release presets `rr` and `act1` keep `export_filter=all_resources` and add:

- include: `LICENSE`, `CREDITS.md`, `docs/THIRD_PARTY_NOTICES.md`, font/KayKit/celestial license texts
- exclude: `tests/*`, `tools/*`, `agents/*`, `generated/*`, `addons/*`, `img/*`, `history/*`, `story/*`, `archive/*`, `quarantine/*`, `docs/reports/*`, `docs/adr/*`, `docs/CHARACTERS/*`, `docs/SYSTEMS/*`, `docs/lore/*`, `scenes/debug/*`, `scenes/tests/*`, `character/inspiration/*`, `build/*`, `.github/*`, `bin/*`

Must not exclude: `characters/`, `character/` (except `character/inspiration/*`), `music/`, `sounds/`, `content/`, `assets/`, `scripts/`, `scenes/menu/`, `scenes/reval_east/`, `docs/data/`.

`rr-diagnostic` (`runnable=false`, `./build/diagnostic/rr.dmg`) keeps `tests/` and `tools/` for packaged acceptance that must run inside a pack. It still excludes `generated/`, addons, report docs, and `build/`.

`generated/.gdignore` hides rebuild/evidence from the Godot filesystem after the P0-201 cat runtime move to `assets/characters/cat/`. Burgher rebuild-brief tests now open those JSON files through `ProjectSettings.globalize_path`, not `ResourceLoader`.

## Regression

- `python3 tools/verify_shipped_resources.py --check` compares `export_presets.cfg` to the manifest.
- `python3 -m unittest tests.python.test_verify_shipped_resources -v` covers parser, filter semantics, and CLI JSON basename output.
- CI: Ubuntu contract check; macOS `desktop-export-smoke` runs `--dmg ./build/rr.dmg --preset rr` after the `rr` export.
- Pre-commit: same contract when the preset/manifest/verifier files are staged.

## Verification (2026-09-09)

| Check | Result |
|-------|--------|
| Python shipped-resource tests | 7/7 pass |
| `--pck build/inventory/rr-after.pck --preset rr` | pass, 5670 / 878,530,075 |
| `--pck build/inventory/act1-after.pck --preset act1` | pass, same 5670 / 878,530,075 |
| `--dmg ./build/rr.dmg --preset rr` | pass, PCK 5670 / 878,530,075; DMG 921 MiB |
| Frozen `build/act1/rr.dmg` SHA | unchanged `ea3cf414...eafbdc` |
| Headless editor `--quit` after `generated/.gdignore` | pass; no `generated/` import |
| `--filter=test_cat_rig` | 8/8 |
| `--filter=test_demo_walkthrough` | Start-Mart-pickup pass |
| `--filter=test_transition_manifest` | 6/6 |
| `--filter=test_act1_packaged_acceptance` | 8/8 |
| `--filter=test_music_director` (isolated) | 13/13; combined filter after walkthrough can leave cycle progress set |
| Burgher JSON evidence tests | pass via filesystem `globalize_path` |
| Burgher craft_boda / merchant_stone mesh-builder tests | still fail: `add_production_model` wires only merchant_timber. Not an export regression. Timber mesh-builder 1/1 pass. |

`rr.dmg` on disk grew versus the July 25 828 MiB image because the current tree has more imported content (soundtrack `.mp3str` 706,952,999 vs 634,422,951). The same-worktree exclude_filter still cut 42.9 MiB and 1221 files from an empty-exclude pack of this tree.

## Non-goals

- Full music-library take reduction (P0-180).
- Rebinding the frozen Act 1 DMG SHA.
- Blanket-ignoring `characters/` or `character/`.
- Deleting `generated/` from Git.
