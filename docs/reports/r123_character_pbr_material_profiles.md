# R-123 (P0-147): character PBR material profiles

Status: verified 2026-10-06.

- `CHARACTER_PBR_MATERIAL_PROFILES` in `assets/characters/shared/shared_character_rig.gd` gives every cloth, leather and metal zone its own roughness/metallic baseline (cloth 0.82-0.94 / 0.0, leather 0.50-0.68 / 0.0, plate 0.28 / 0.95, mail 0.72 / 0.55). Per-pixel shading is forced, so no body material is unshaded.
- Tests: `test_legacy_shared_character_material_profiles_separate_cloth_leather_and_metal` and `test_shared_character_no_body_material_is_unshaded`. Run: `--filter=test_character_rig` gives 35 tests, 0 failures.
- Capture: `images/characters/r123/closeup_front_idle.png`. The wool tunic is matte with no sheen, and the leather apron and boots carry a visible specular response. Kalev's current wardrobe has no iron zone, so the metal response is covered by the unit test only.
- Remaining gap: a turntable that includes a mail or plate wearer. Tracked as a follow-up task.
