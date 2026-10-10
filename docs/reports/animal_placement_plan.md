# Animal models: audit and placement plan (2026-10-07)

Status: first slice implemented (`CityFauna`); the rest is planned below.

## Audit of the storybook model list

| Models | Verdict | Why |
|---|---|---|
| Mart, Aita, Ellen, watchman, Henning, Jurgen, Kaja (`assets/storybook/<id>/`) | **Deleted** | Procedural, never brought to high realism. No scene loaded them: every live human uses the MPFB bodies in `assets/characters/variants/` (ADR 0022). Only the debug showcase and tests referenced them. |
| 21 fitted wearables (`<person>_mail`, `_helmet`, `_cape`) | **Deleted** | Fitted only to those seven bodies. Nothing else loaded them. |
| `equipment/shield` | **Deleted** | No item or scene used it (tests used it as a fixture). |
| `equipment/sword`, `equipment/hammer` | **Kept** | `item.plain_sword.json` and `item.forge_hammer.json` mount them. |
| robin, hooded crow, gull, duck | **Kept, weak** | Live bird flight (`MapViewBirdAssets.ANIMATED_MODELS`) and ambient ducks use them. They are procedural: the gull's bill and wing texture read poorly in close-ups (`docs/reports/images/bird_flight_realism_2026-10-07/gull_closeup.png`). Replace with authored sculpts (see Phase 3) rather than delete, because flight needs a model. |
| goose | **Kept** | The authored greylag with a gait rig, loaded by `MapViewMedievalAnimalModels` and tested. |
| horse | **Replaced (2026-10-08)** | The old Hunyuan3D body read as a dog on stilts. A new anatomical bay horse is built by `tools/assets/build_horse_source.py` and rigged on the shared mammal rig; see `assets/storybook/README.md#horse`. The duplicate `assets/animals/medieval/medieval_horse.*` was deleted. |

Removed with them: 29 `SOURCES.csv` rows, `storybook_character.gd`, the human halves of `test_storybook_models.gd`, and the people/equipment half of `scenes/debug/storybook_showcase` (now an animal-only review scene). The Blender generator no longer rebuilds the humans, wearables or shield. About 33 MB of GLB and textures left the repo tree.

## Where the animals were: nowhere

The seamless city (`reval_city`, ADR 0031) is the playable world, but it has no ground fauna. The ambient layers (`MapViewUrbanFauna`, `MapViewPennedFauna`) are keyed to legacy district map IDs and map cells, so every high-quality mammal model (cat, dog, horse, rat, hen, goose, pig, cow ×2 coats, sheep, goat, hare, fox, boar) was invisible in the game, apart from Kalev's forge cat.

## Phase 1 (done): `CityFauna`

`scripts/city/city_fauna.gd` places the existing models from plan data, so placements follow the plan:

| Where (plan anchor) | Animals |
|---|---|
| Forum | dog, cat, tethered cart horse, three hens |
| Fish landing | two cats, a dog |
| Pikk granary | two rats (flee), a cat |
| Lai bakery, Vene brewery, Harju smithy, castle barracks | cat; dray horse; horse and dog; two horses |
| Karja farmsteads (slaughter yard, mill, wells) | two pigs, a cow, hens, three geese, goats |
| Gates (Viru, Harju, Coastal, Karja) | tethered horse; dog; cattle and sheep arriving by the cattle road |
| Fallow fields | grazing sheep, cattle and goats, cycled by field |
| Field margin | a hare on every third ploughed field, a fox on the southern ones |

Rules: homes are nudged to dry, gentle ground off every foundation and landmark site; yards are blocked by footprints; models are scaled 1.83/2.0 so a cow stands beside Kalev (1.83 m) as it did beside the 2-unit person in the district maps. Only groups within 85 m of Kalev exist (freed beyond 120 m), capped at 18 actors, because the city's frame time is already over budget on skinned rigs (`docs/SYSTEMS/SEAMLESS_CITY.md`). Visual only: no collision, no GameState, nothing saved.

Verify: `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_fauna`; plates with `tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_fauna.tscn` (`docs/reports/images/city/fauna_*.png`).

## Phase 2 (planned): behaviour and time

- Night: yard animals sleep or go in (cat `Sleep`, hens roost); horses stay tethered. Needs the session clock from `MapViewRuntime`.
- Cats hunt the granary rats and dogs play, via `MapViewCompanionIntent` (district maps already do this).
- Ducks and geese on the moat and the mill pond. Needs a water-aware placement and a swim clip; no model has one.
- Wild boar and deer for the hinterland streaming group (ADR 0027) once it exists; the boar model is ready.
- Frame-time check with `tools/profile_reval_city.tscn` before raising `MAX_ACTORS`.

## Phase 3 (planned, needs a task naming files): bird quality

Replace the four procedural storybook birds with authored sculpts, following the hen route (`tools/assets/import_authored_birds.py`, a licensed Sketchfab source recorded in `SOURCES.csv`). Gull first: it is the bird most seen over the harbour. Then the hooded crow, robin and mallard.
