# Music recovery after audio quarantine

Date: 2026-07-16
Status: resolved by P0-031

## Symptom

The main menu, forge, and playable town districts became silent.

## History and root cause

P0-027 conservatively classified every legacy MP3 as `unknown rights`. P0-029 then moved those sources under `quarantine/.gdignore`, and P0-030 removed their broken `AudioStreamPlayer` references from active scenes. This correctly protected builds from unlicensed assets but left all formerly musical scenes without a safe replacement.

The recovery deliberately does not restore the old MP3 files. Their source and commercial rights remain undocumented in `assets/SOURCES.csv`.

## Resolution

`MusicDirector` is an autoload that routes the main menu, forge, and active town scenes to distinct deterministic procedural themes. It generates looping `AudioStreamWAV` resources in memory from repository-owned GDScript, so no quarantined source is restored or imported.

The centralized route is also the initial music-hook boundary anticipated by P1-017. The generated themes are prototypes, not the final soundtrack. Final recorded stems, runtime streaming, the 12-minute soundtrack budget, and complete rights reporting remain P2-014/P3-009/P3-013 work.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --script tools/test_music_director.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 5
python3 tools/generate_asset_inventory.py --check
python3 tools/validate_asset_sources.py
```

The dedicated test verifies every active route creates non-empty looping PCM. The main-menu smoke verifies the autoload and startup path load without parser, missing-resource, or quarantined-audio errors. Asset checks verify that no unknown-rights audio returned to active import paths.
