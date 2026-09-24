# Fresh Kalev live integration — 2026-09-13

## Result

The stable player-view scene `res://assets/characters/kalev/kalev.tscn` now instantiates `kalev_fresh/kalev_fresh.glb`. Every map runtime that loads the stable scene therefore uses the rebuilt character without map edits. The live rig retains stable identity `char.kalev`, the shared health-ring presentation, canonical animation names, the `handslot.r` equipment socket, and the existing inventory-driven weapon synchronization.

Kalev starts in fitted forge clothing: linen shirt, smith apron, hose, and boots. The former cape and permanent variant hammer were removed from the live variant. Weapons now appear only when equipment state supplies one, and clothing or armor swaps reuse the same skeleton and animation player.

The fresh walk and run clips hold both feet at nearly equal height during their load exchange, so the fresh rig uses their authored half-cycle as its contact authority. This preserves synchronized left/right footsteps without mixing competing detectors during animation blends; all other characters keep the shared pose-height behavior.

## Visual evidence

- `docs/reports/images/kalev_live_integration/lower_town_gameplay.png` — production Lower Town map at the shipped gameplay orthographic size.
- `docs/reports/images/kalev_live_integration/lower_town_closeup.png` — inspection crop of the same production map, stable Kalev scene, fitted outfit, health ring, and the production hammer scene used by inventory synchronization. The capture stages that hammer directly; automated runtime tests cover inventory-driven equip and unequip.

The deterministic capture command is:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_kalev_live_integration.gd
```

## Verification

- Focused live integration suite: 10 files, 113 tests, 0 failures, 0 errors. Coverage includes character rig, fitted wardrobe, inventory equipment, combat room, hammer presentation, Kalev rebuild and live scene, map runtime, save envelope, and save service.
- Character rig suite: 34 tests, 0 failures, 0 errors.
- Fresh asset verifier: 51,998 body triangles, 8 independently hidden body regions, 76 animation clips, 6 fitted garments; body SHA-256 `c5de85fb2dc6cd35ed354f1715be25a0094852641c7015dafa9464ac7fd9a376`.
- Lower Town checked startup smoke completed successfully.
- `git diff --check` completed successfully; Git reported only an existing CRLF normalization warning for `assets/SOURCES.csv`.
- Independent reviewer approved P0-215 after the fresh foot-contact detector was made phase-only and checked across dense walk/run samples and locomotion transitions.

The broader player action suite passes 19 of 20 tests. Its existing synchronous collision-world test still reports that a dodge crosses a newly added wall before the physics server registers it; this path does not load or inspect the 3D Kalev rig. Player animation selection, equipment attack profiles, dodge animation mapping, and action recovery checks pass.

## Review boundary

This integration changes player presentation only. It does not change map content, save schema, inventory IDs, combat values, movement values, or the stable character ID. The rebuilt body currently has no generated distance LOD meshes, so it remains visible as LOD0 at all gameplay distances until fresh-model LOD assets are authored.

Activation carries forward the accepted P0-214 visual limits: projected side seams, coarse shoulder/neckline and hem tailoring, and a rigid hand grip. The current asset is an in-game baseline and does not yet reach final Witcher 3-level character finish.
