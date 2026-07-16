# Godot import sidecar and cache policy (P0-023)

Recorded: 2026-07-16

## Summary

Reval Rebel should track source assets and Godot `*.import` sidecars, but should not track Godot's generated import cache. A clean clone can rebuild the cache with Godot 4.7.1 from tracked sources plus sidecars. The regenerated cache is local machine output under `.godot/` and remains ignored by Git.

## Audit scope

Inspected:

- tracked `*.import` sidecars from Git
- local and clean-clone Godot cache folders
- `.gitignore`
- `docs/SETUP.md`
- clean-clone headless import behavior using `/Applications/Godot.app/Contents/MacOS/Godot`

## Current repository inventory

| Item | Count / status | Policy result |
|------|----------------|---------------|
| Tracked `*.import` sidecars | 703 | Keep tracked when the matching source asset is tracked and import settings matter. |
| Tracked `.godot/**` files | 0 | Correct. Must stay untracked and ignored. |
| Tracked legacy `.import/**` cache files | 0 | Correct. Must stay untracked and ignored. |
| Tracked sidecars without tracked source asset | 28 | Audit finding. These are not valid runtime import records and should be removed or reunited with source assets in the asset-cleanup work. |
| Local `.godot/` cache after import | about 1.0 GB, 1350 files in clean-clone run | Generated cache. Ignore and regenerate. |

Tracked sidecars by importer:

| Importer | Type | Count |
|----------|------|-------|
| `texture` | `CompressedTexture2D` | 542 |
| `mp3` | `AudioStreamMP3` | 160 |
| `font_data_dynamic` | `FontFile` | 1 |

Tracked source asset counts relevant to those sidecars in Git were 480 `.png`, 34 `.jpg`, 159 `.mp3`, 1 `.svg`, and 1 `.ttf` files. Some sidecars target sources that are no longer tracked, listed below as an audit finding.

## Policy

### Keep tracked

Track these files when they belong to an approved, prototype, or otherwise intentionally imported asset path:

1. Source media files used by Godot, for example `.png`, `.jpg`, `.svg`, `.ttf`, and `.mp3`.
2. The matching `source.ext.import` sidecar.
3. Project resources and scenes that reference those imported assets.

Reason: Godot sidecars are metadata, not disposable cache. They store the importer, resource type, stable UID, source path, destination cache path pattern, and import parameters such as texture compression, mipmap generation, alpha handling, font rendering, and MP3 loop settings. Without the sidecar, a clean clone may import with editor defaults and change runtime appearance, audio behavior, or resource UIDs.

### Ignore and regenerate

Do not track these generated files or folders:

1. `.godot/` - Godot 4 editor/import cache, including `.godot/imported/*.ctex`, `.godot/imported/*.mp3str`, `.godot/imported/*.fontdata`, `.godot/imported/*.md5`, `.godot/uid_cache.bin`, editor layouts, filesystem caches, and script documentation caches.
2. `.import/` - legacy Godot 3 import cache folder, if it appears after opening the project with an older editor or external tooling.
3. `/android/` and export/build output folders covered by existing setup/export practice.
4. Generated translation/import artifacts from documentation manifests, for example `assets/SOURCES.csv.import` and `assets/SOURCES.*.translation`.

Reason: these files are derived from tracked sources, tracked `*.import` sidecars, `project.godot`, and the installed Godot version. They are platform/editor output, can be large, and are safely recreated by `godot --headless --editor --quit`.

### Review rule for sidecar diffs

Changes to tracked `*.import` files are allowed only when they are intentional and reviewed. Typical valid reasons are:

- adding, removing, renaming, or moving a source asset
- changing import settings in the Godot editor
- accepting a Godot version migration that adds or renames import parameters
- removing an orphan sidecar together with an asset cleanup decision

Do not commit sidecar churn produced by opening the project in an unpinned Godot version.

## Clean-clone verification

Clean clone used for verification:

```bash
rm -rf /tmp/rebel-reval-p0-023-clean
git clone --no-hardlinks . /tmp/rebel-reval-p0-023-clean
cd /tmp/rebel-reval-p0-023-clean
rm -rf .godot
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --quit
```

Result:

| Check | Result |
|-------|--------|
| Godot version | `4.7.1.stable.official.a13da4feb` |
| Headless import exit code | 0 |
| `.godot/` cache created | Yes |
| `.godot/` Git status | Ignored (`!! .godot/`) |
| Generated imported files | 1350 files under `.godot/imported` |
| Generated cache size | about 1.0 GB |
| Import log errors | None |
| Import log warnings | One pre-existing input setting warning for `input/ui_shift/deadzone` |

The clean clone regenerated cache files from tracked sources and sidecars. Existing required import settings were preserved. Godot 4.7.1 also added explicit default fields to 516 tracked sidecars (`compress/uastc_level`, `compress/rdo_quality_loss`, texture `process/channel_remap/*`, and `modulate_color_glyphs` for the font sidecar). No existing sidecar setting was removed. Treat these 4.7 default additions as version-normalization diffs and review them separately before committing, especially while other asset cleanup work is deleting or quarantining assets.

## Audit findings to resolve outside P0-023

The repository currently contains 28 tracked `*.import` sidecars whose matching source file is not tracked in Git:

```text
assets/UI/character-hud/image-1.png.import -> assets/UI/character-hud/image-1.png
assets/UI/character-hud/image-2.png.import -> assets/UI/character-hud/image-2.png
assets/UI/character-hud/image-3.png.import -> assets/UI/character-hud/image-3.png
assets/UI/character-hud/image-4.png.import -> assets/UI/character-hud/image-4.png
assets/UI/character-hud/image-6.png.import -> assets/UI/character-hud/image-6.png
assets/UI/character-hud/image-7.png.import -> assets/UI/character-hud/image-7.png
assets/UI/character-hud/image.png.import -> assets/UI/character-hud/image.png
assets/bestiary/image-36.png.import -> assets/bestiary/image-36.png
assets/bestiary/image-37.png.import -> assets/bestiary/image-37.png
assets/bestiary/image-38.png.import -> assets/bestiary/image-38.png
assets/bestiary/image-39.png.import -> assets/bestiary/image-39.png
assets/bestiary/image-40.png.import -> assets/bestiary/image-40.png
assets/bestiary/image-41.png.import -> assets/bestiary/image-41.png
assets/tiles1.png.import -> assets/tiles1.png
characters/famous/image-26.png.import -> characters/famous/image-26.png
characters/famous/image-5.png.import -> characters/famous/image-5.png
characters/order/image.png.import -> characters/order/image.png
characters/order/teutonic-1.png.import -> characters/order/teutonic-1.png
characters/rebels/black-1.png.import -> characters/rebels/black-1.png
characters/rebels/image-5.png.import -> characters/rebels/image-5.png
characters/streets/peddler/child_sword.png.import -> characters/streets/peddler/child_sword.png
characters/streets/peddler/gossip_neighbor.png.import -> characters/streets/peddler/gossip_neighbor.png
characters/workers_quarter/image-22.png.import -> characters/workers_quarter/image-22.png
characters/workers_quarter/image-9.png.import -> characters/workers_quarter/image-9.png
characters/workers_quarter/tomas/Pasted image 20250824201419.png.import -> characters/workers_quarter/tomas/Pasted image 20250824201419.png
characters/workers_quarter/valentin/Pasted image 20250824201515.png.import -> characters/workers_quarter/valentin/Pasted image 20250824201515.png
scenes/menu/intro-music.mp3.import -> scenes/menu/intro-music.mp3
scenes/reval_east/marek_carpenter.png.import -> scenes/reval_east/marek_carpenter.png
```

Recommended follow-up: resolve these during active asset-path cleanup by either restoring the source asset with documented provenance or deleting the orphan sidecar. Do not keep an orphan sidecar as a cache surrogate.

## Maintainer workflow

For a clean import check from repository root:

```bash
godot --headless --editor --quit
git status --short --ignored .godot .import
git diff -- '*.import'
```

Expected policy-compliant result:

- `.godot/` may appear as ignored.
- `.import/` should not appear; if it does, it should be ignored and removed locally.
- `*.import` diffs must be reviewed. If they only reflect a planned Godot version normalization, commit them as a deliberate migration. Otherwise revert them before committing unrelated work.
