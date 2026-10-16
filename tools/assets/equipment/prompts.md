# Equipment prompt templates

Templates for the equipment pipeline in [`docs/SYSTEMS/EQUIPMENT_VARIANTS.md`](../../../docs/SYSTEMS/EQUIPMENT_VARIANTS.md) (task R-2003). Fill the `<...>` slots from the item's historical checklist; keep the art bible's forbidden list in every prompt. Copy the final prompt verbatim into the item manifest (`items/<variant>.json`) and into `assets/SOURCES.csv`.

## 1. Rigid item reference (Leonardo -> Meshy)

Model: `gpt-image-1.5` at 1536x1024 when the outline matters (blades, helmet profiles); Nano Banana (`gemini-2.5-flash-image`) only at its listed sizes, 1248x832 or 1184x864 (1536x1024 and 1024x1024 fail). One object per image, `num_images=1`, and look at every image before Meshy: Meshy copies the reference faithfully, mistakes included.

> Museum catalogue photo of a single object: <item>, 14th century, Baltic (Reval 1343), <real size in cm>, <without shaft / without wearer>. <outline, stated as shapes plus what it must NOT have: "base ROUNDED, no flat shoulders, no corners, no barbs"; "both halves mirror each other exactly">. <construction: socket, rivets, seams, lining>. <material: hand-forged wrought iron, dull grey-black, faint hammer marks / undyed wool / vegetable-tanned leather>. <wear w0/w1/w2: new and clean / used, a few small brown rust spots / battered, dented, rust, patched>. No ornament, no engraving, no gold, not polished, not chrome, not fantasy. <pose: lying horizontally, <base> on the left and <tip> on the right, seen almost straight from above with a slight three-quarter tilt / three-quarter view from the front-left and slightly above>, whole object in frame with margin, plain pure white background, soft even studio light, no cast shadow, no straps hanging loose, no hands, no people, no text.

Rules learned on the pilot:
- Nano Banana turned "leaf-shaped spearhead" into an asymmetric shouldered blade twice; gpt-image-1.5 followed the outline once the forbidden shapes were named.
- Long hafted weapons: generate only the iron head (the shaft is built in Blender, see the cleanup script). Meshy cannot resolve a 2 m pole 3 cm thick.
- Wearables: no loose straps or chin cords in the reference; Meshy fuses them onto the nearest surface. Straps and liners are modelled in Blender.

## 2. Meshy image-to-3D

`meshy_generate_3d` with `image=<absolute jpg path>`, `pbr=true`, `texture=true`, `model_type=standard`, `target_polycount` 3000 (weapon head), 6000 (helmet), `timeout_seconds=540`. If the MCP call times out, the task keeps running on Meshy's side: never resubmit, list the jobs instead ([`agents/rebel-art/playbook.md`](../../../agents/rebel-art/playbook.md)). Move the GLB from `generated/meshy/` (not gitignored) to `build/<set>/<id>_meshy_raw.glb` at once and record its SHA-256 in the manifest.

## 3. Tileable textile / material plate (Leonardo or ComfyUI -> derive_tileable_pbr.py)

> Flat texture photograph, shot straight-on and filling the entire frame edge to edge: <surface>, medieval, <wear>. <structure: weave (tabby / 2/2 twill), quilting channels <n> cm apart running vertically, riveted mail rings 8 mm, grain running exactly vertically>. <colour from the art bible palette: undyed grey-brown wool / woad blue / madder red / pale grey-cream ash>. <wear: faint grime, pilling, darns / small dents>. No gloss. Even diffuse light, no shadows, no vignette, no perspective, no objects, no edges, no text, no watermark.

- Leonardo: Nano Banana 1184x864 (the derive script crops the centre square).
- ComfyUI: [`comfyui_tileable_textile.json`](comfyui_tileable_textile.json) is the Chroma1-HD graph from the art playbook; set node `4` text, node `7` seed. About 5 min per image on this Mac, so queue it with `POST /prompt` and poll `/history/<id>` instead of `comfyui_run_workflow`.
- Generators drift pale and grey (the pilot ash came out as white laminate): fix the colour with `--tint`/`--gain` in `derive_tileable_pbr.py`, never with a material node (the glTF exporter drops colour-mix nodes).
