# Asset Archive

This directory stores approved legacy assets that are not wired into the current vertical slice but should remain available for future districts, phases, or soundtrack tasks.

`archive/.gdignore` makes Godot skip this entire tree, mirroring the `quarantine/` import policy. Provenance paths in `assets/SOURCES.csv` keep the original `music/...` or `sounds/...` repository-relative path even when the binary file lives here.

## Current contents

- `archive/music/` - district ambient and battle tracks restored by P0-031 but not yet routed by `MusicDirector`

Active runtime audio remains under `music/` and `sounds/` for menu, forge, town, and door SFX.

## Restore to runtime

Move both the source file and its matching `.import` sidecar back to the mirrored original path (for example `archive/music/harbor/...` -> `music/harbor/...`), then wire the track in `scripts/global/music_director.gd` or the relevant scene before shipping.
