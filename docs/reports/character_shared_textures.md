# Shared humanoid texture references

Status: implemented 2026-09-09. Companion contract: [`docs/CHARACTER_GENERATION.md`](../CHARACTER_GENERATION.md).

Palette-neutral character family maps (512 px cloth, leather, skin, hair, metal) were byte-identical across bodies and LODs, but every GLB embedded a fresh copy and Godot `gltf/embedded_image_handling=1` extracted `<body>_hero_tex_*.png` beside it. This change keeps the approved RPG look (same PNG bytes, same material factors, same rig/LOD/UV islands) and makes the generator plus import contract share one file set.

## What changed

- Canonical files live in `assets/characters/shared/textures/hero_tex_<family>_*.png`. Packed ORM keeps the `ao-hero_tex_<family>_roughness` stem.
- `tools/share_character_textures.py` harvests unique embeds, writes those PNGs, rewrites runtime GLB `images[]` to relative URIs, and only then deletes per-body extracts. Distinct maps (hash mismatch for the same glTF name) stay embedded. `kaykit_barbarian.glb` is untouched.
- Body and LOD exporters call `link_exported_character_glb` so a Blender rebuild cannot re-seed per-body copies. `rebuild_hero_character.sh` runs `--apply` before Godot import.
- Godot still uses `gltf/embedded_image_handling=1` for any remaining unique embed. URI maps are not extracted. Materials stay per-GLB because palette is `baseColorFactor` / shader params.

## Before / after (worktree 2026-09-09)

Recalculated after ongoing character edits. Source-byte totals are not Git LFS or PCK savings.

| Surface | Before | After |
|---|---:|---:|
| Per-body extracted `*_hero_tex_*.png` | 510 files, 122.09 MiB | 0 |
| Unique PNG hashes among those files | 15 (495 exact copies, 113.20 MiB waste) | 15 shared files, 3.23 MiB |
| GLB files under `assets/characters/shared/` | 43 files, 206.64 MiB | 43 files, 90.20 MiB |
| Embedded GLB image payloads | 511 images, 116.44 MiB (16 unique hashes, 3.24 MiB unique including KayKit) | family maps URI-linked; KayKit still embedded |
| Tracked `assets/characters/shared/` (git ls-files at start) | 1106 files, 319.21 MiB | see commit `git ls-files` after this lands |
| Godot `.godot/imported` family maps | 1255 body-prefixed files, 167.04 MiB | 40 shared `hero_tex_*` files, 5.41 MiB |

A full macOS `rr.dmg` / PCK was not rebuilt in this pass. Packaged loading of the shared maps is the same `res://assets/characters/shared/textures/hero_tex_*.png` path the editor import uses; character rig, wardrobe, and showcase tests load those imported scenes. PCK size will follow unique imported texture resources plus smaller GLB BIN chunks, not the 229 MiB raw-source delta above.

## Verification

```bash
python3 tools/share_character_textures.py --verify
python3 -m unittest tests.python.test_share_character_textures tests.python.test_character_fidelity_tiers
python3 tools/verify_asset_lint.py
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_character_rig,test_character_wardrobe,test_asset_showcase
```

Idempotence: a second `--apply` reported `linked=0, already=510, pruned=0`. A second Godot `--import` did not recreate per-body PNGs and did not emit missing `*_hero_tex_*` resource errors.
