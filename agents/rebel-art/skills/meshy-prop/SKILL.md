---
name: meshy-prop
description: Turn a furniture or household prop brief into a runtime catalog object - Leonardo reference image, Meshy image-to-3D, Blender normalize to real size and axes, catalog record, provenance, class/wear variants in HouseholdLayout.
---

# Meshy prop: reference image to catalog furniture

Status: production pipeline (first run: the household bed set and cradle, task **R-2078**, 2026-10-16). Siblings: [`meshy-animal`](../meshy-animal/SKILL.md) (rigged fauna), [`meshy-human`](../meshy-human/SKILL.md). Rigid props only: no skinning, no animation. Shipping into `assets/` needs a board task naming the files (asset freeze P0-040).

## 1. Brief: one object per class and wear

Decide the variant matrix before generating. Households have three furnishing tiers (`HouseholdLayout.TIER`: poor, mid, rich; census `great` is rich with extras) and three wear levels. Give each tier at least two models where it shows (the head couple's bed, the table), and put the wear into the model itself for poor pieces (cracked boards, patched cloth, straw spilling); the runtime wear tint (step 6) only darkens and grimes, it cannot crack wood. Check period plausibility first: 1343 Reval is Hanseatic Gothic - no classical meander, no turned spindles, no Renaissance or Victorian forms, no machine-smooth pine.

## 2. Reference image (Leonardo, Nano Banana)

`leonardo_generate_image`, `model_id=gemini-2.5-flash-image`, **1248x832** (square sizes are rejected), `num_images=1`. Probe one request before a batch (402 = no tokens). Prompt grammar that worked:

> Game asset reference photo of a single object: <what, who owned it, century and place>, <real size in metres>. <materials and construction>. <bedding / contents>. <condition: worn, dirty / used and tidy / rich, clean>. Not modern, not polished. Three-quarter view from the front-left and slightly above, whole object in frame with margin, plain pure white background, soft even studio light, no cast shadow, no people, no text, no modern objects.

Inspect every image before Meshy: Meshy copies mistakes faithfully. In the R-2078 run the first craftsman's bed came out as a modern catalogue pine bed and the curtained bed had a Greek-key cornice; naming the construction ("hand-adzed oak, gabled plank headboard, pegged mortise joints") and the forbidden styles fixed both.

## 3. Meshy image-to-3D

`meshy_generate_3d` with `image=<abs jpg path>`, `texture=true`, `pbr=true`, `model_type=standard`, `target_polycount` 6000 (small) to 20000 (curtained bed), `timeout_seconds=540`. Six calls in parallel finished in about 10 minutes. If the MCP call times out, the task keeps running: list jobs instead of resubmitting (art playbook). Move the GLB and preview from `generated/meshy/` (not gitignored) to `build/<set>_meshy/<id>.glb` at once and record its SHA-256.

Meshy output: one mesh, about 1.9 units on its longest axis, centred, 2048 px base colour + metallic-roughness + normal. Orientation varies per scan.

## 4. Normalize in Blender

Write a manifest like [`tools/assets/meshy_prop/beds.json`](../../../../tools/assets/meshy_prop/beds.json) (id, Leonardo generation, Meshy task, raw SHA-256, prompt, `yaw`, `size` [x length, y height, z depth] in metres, `tris`). Then:

```bash
B=/Applications/Blender.app/Contents/MacOS/Blender
# Which way does the raw scan face? Red stick +X, blue stick glTF +Z (front).
$B -b --factory-startup --python tools/assets/meshy_prop/render_prop_views.py -- \
  --glb build/<set>_meshy/<id>.glb --out build/<set>_meshy/views/<id>.png --px 300
# Normalize every prop of the manifest and render the runtime views.
python3 tools/assets/meshy_prop/build_props.py tools/assets/meshy_prop/<set>.json [--only <id>]
```

Conventions the runtime expects: long side along X, the usable front (the side people step to) facing glTF +Z (`"front": 1` in `HouseholdLayout.PIECES`), the origin at the footprint centre on the floor; for beds the head at local -X (`HouseholdLayout._bed_slots`). Pick `yaw` from the raw views (90 turns Blender +Y to -X). `size` scales per axis: keep the stretch over a uniform scale under ~25 % or the texture smears. Textures are capped at 1024 px JPEG; a bed lands at 0.8-1.6 MB. The `NORMALIZED` log line prints `top_h`, the highest surface over the middle of the footprint under 1 m: start the catalog `lie_h` / `seat_h` about 0.05 m below it.

## 5. Catalog, provenance, import

- Catalog record `content/objects/<category>/obj.<id>.json` with `model.glb`, `measured_size_m` and an existing `prop_kind` (or none; unknown kinds fail validation). Material and space values are enums: see the validator message.
- `python3 tools/object_catalog.py sync`, `python3 tools/render_object_previews.py obj.<id> ...`, `python3 tools/object_catalog.py index`, `python3 tools/validate_object_catalog.py` (filter its output for your ids; unrelated rows may already fail).
- `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` writes the `.glb.import` and the extracted `<id>_Image_0/1.jpg`, `<id>_normal.jpg` (commit all sidecars).
- `assets/SOURCES.csv`: one row for the GLB (full prompt, Leonardo generation, Meshy task, raw and output SHA-256, normalize parameters) and one per extracted texture; `python3 tools/validate_asset_sources.py`.

## 6. Variants at runtime (households)

- Per-tier pools in `HouseholdLayout` (`HEAD_BEDS`, `OTHER_BEDS`, `BED_FALLBACK`); `bed_piece(building_id, household, rank)` picks by a hash of the house, never by the furnishing RNG, so adding a model does not move other houses' furniture choices.
- `HouseholdLayout.wear_of` / `tone_of` give each house a wear (0 kept, 1 used, 2 worn; odds by tier in `WEAR_ODDS`) and a wood tone; `CityInteriors._instance(object, state, wear, tone)` darkens the albedo and multiplies a seamless grime noise through the material's detail layer. One material copy per combination is shared by all houses.
- Docs: [`docs/SYSTEMS/HOUSEHOLDS.md`](../../../../docs/SYSTEMS/HOUSEHOLDS.md).

## 7. Verify

- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_household_layout`
- `tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_households.tscn -- --city-spawn=poi.forum --city-hour=12.5 --tag=beds --houses=8` writes `_bed.png` close-ups of each house's head bed next to the cutaway and eye shots.

## Known limits

- Meshy bakes soft lighting into the base colour, so a scan reads slightly flat under strong interior light.
- Curtains and bedding are one rigid mesh with the frame: nothing moves, nobody can draw the curtains.
- The runtime wear tint cannot add damage; new wear needs a new model.
