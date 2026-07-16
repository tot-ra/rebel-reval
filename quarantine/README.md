# Asset Quarantine

This directory is a Godot import quarantine for TODO P0-029.

`quarantine/.gdignore` makes Godot skip this entire tree. Files are stored under a mirror of their original repository-relative path, for example `quarantine/music/menu/Menu.mp3` preserves the original `music/menu/Menu.mp3` path for provenance, review, and possible restoration.

## Policy

- Hard quarantine: assets marked `unknown rights`, `archive`, or equivalent commercial-risk status in `assets/SOURCES.csv` must live under this directory and must not be referenced by runtime scenes or scripts.
- Soft quarantine: unreferenced `prototype` or `inconsistent` assets are also moved here because they are not approved for commercial runtime use and are not needed by active scenes.
- Runtime exception: referenced `prototype` visual assets may remain in place only to avoid breaking current active scenes. They are not approved for commercial release and must be replaced or promoted with provenance/approval by P0-040.
- Inconsistent legacy assets (player frame sets, superseded HUD, legacy tiles) were moved here by P0-030.
- No new runtime scene may reference `res://quarantine/...` or any original path whose source file has been moved here.

## Restore procedure

To restore a quarantined asset for review, move both the source file and its matching `.import` sidecar back to the mirrored original path, then update `assets/SOURCES.csv` with documented source, license, edits, and approval before using it in runtime scenes.

## Verification

Run from the project root:

```bash
python3 tools/quarantine_assets.py --check
python3 tools/validate_asset_sources.py
python3 tools/generate_asset_inventory.py --check
```
