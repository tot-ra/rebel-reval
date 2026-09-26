# Realistic human characters — Kalev first (ADR 0022), 2026-09-26

Maintainer request: rework human characters to realistic, historically accurate models
(Kingdom Come: Deliverance 2 / The Witcher 3 reference), all models realistic, key characters
polished further, and the main character modular for clothes, armour and weapons.
Decision record: [ADR 0022](../adr/0022-realistic-human-characters.md). Procedure:
[`CHARACTER_GENERATION.md`](../CHARACTER_GENERATION.md) "Realistic humans".

## Delivered

- New in-repo pipeline `tools/assets/realistic_humans/`: MPFB 2.0.17 + MakeHuman CC0 base body
  shaped by a spec, bound to the shared 41-bone rig with all 76 clips (MakeHuman weights,
  orientation-preserving joint fit), generated skin detail, beard fur shells, recoloured hair
  cards, and a generated 1343 wardrobe with tiling wool/linen/leather/mail/quilted/iron maps.
- **Kalev** (mid-40s Estonian master smith, dossier "Art — Kalev") replaces the photo-projected
  `kalev_fresh` body in `assets/characters/kalev/kalev.tscn`, spawning in the forge outfit.
- Ten wearables fitted to Kalev: `linen_shirt`, `work_tunic` (rolled sleeves), `wool_tunic`
  (belt, purse, knife), `gambeson`, `mail_haubergeon`, `smith_apron`, `hose`, `boots`, `hood`
  (Gugel with shoulder cape), `kettle_hat`; outfits `forge`, `street`, `travel`, `armed`,
  `undress` in `outfits.json`. Weapons use the unchanged `handslot` sockets.

## Evidence (Godot, GL Compatibility capture stage)

![Outfits](images/realistic_humans/kalev_outfits_engine.png)

![Portraits](images/realistic_humans/kalev_portraits_engine.png)

![Before and after](images/realistic_humans/kalev_before_after_engine.png)

## Verification

- `tools/assets/realistic_humans/rebuild.sh kalev` — builds, imports, registers 38 provenance rows,
  `validate_asset_sources.py` and `verify_asset_lint.py` pass (Kalev classified Tier 0 from its spec).
- `--filter=test_realistic_kalev,test_kalev_live_integration,test_storybook_live_integration,test_character_wardrobe`:
  4 files, 23 tests, 0 failures. New `test_realistic_kalev.gd` covers the rig/clip contract, every
  wardrobe region, every garment's equip/hide/restore cycle, all named outfits, rejection of
  wearables fitted to another body, and the fur-shell material contract.
- `generate_active_docs_report.py --check` clean.

## Known limits / next

- Face: geometry, eyes, beard and hair are credible, but the skin still reads cleaner than the
  old photo projection at dialogue distance; a hero face texture pass (photo-grade albedo and
  wrinkle normal in the face region) is the next Kalev polish item.
- Cloth is skinned, not simulated; sleeves still hint at biceps in the full-sleeve tunic.
- Hands are a baked loose fist (no finger bones in the shared rig); no facial animation.
- Named cast, NPCs and crowds are not yet migrated; `kalev_fresh` assets remain for its preview
  scene and tests until retired.
- The environment post-grade was tuned for ADR 0018 and still needs naturalistic recalibration.
