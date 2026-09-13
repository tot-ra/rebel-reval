# P0-214: original Kalev reconstruction

Started 12 September; technical checks completed 13 September 2026; visual acceptance remains open. Maintainer request: create the protagonist from scratch without looking at the existing model, preserving realistic historical-RPG ambitions and interchangeable clothes, armour and weapons.

## Inputs and design

Only the new original references in `assets/characters/kalev_rebuild/reference/` feed reconstruction and skin projection. Front and back plates establish a 42-year-old Baltic smith: working strength, mature weathered face, dark brushed-back hair, grizzled beard, natural adult proportions, modest linen braies. The head closeup matches that new identity. Existing character geometry, screenshots, anatomy generators and palettes were not consulted. Shared runtime API and CC0 skeleton/motion metadata were inspected for compatibility.

Image generation: OpenAI ImageGen, model revision not exposed by the tool, seed not exposed. Original prompts and fresh source plates are retained with this task. Hunyuan3D: local `hunyuan3d-dit-v2-mv_fp16.safetensors`, ComfyUI 0.28.2, MPS, seed 2121343, 24 Euler/simple steps, CFG5.5, 3072 latent resolution, 512 volume grid, surface-net mesh extraction. Front/back are padded to square without cropping. The job uses only those two fresh full-body images. The final decoder chunk size is 64000; an earlier smaller-chunk decode was interrupted, leaving the sampled latent cached.

The only reused authored data is the CC0 KayKit skeleton and 73 animation clips. Idle, Walking_A and Running_B are newly authored for the fresh adult proportions. `inspect_motion_rig.py` removes all mesh/material/image references from the glTF document before importing it into Blender. The target skeleton is fitted to landmarks measured from the new front reference; A-pose geometry is bound into a T-pose for compatible motion deltas.

## Deliverable

The independent review scene is `assets/characters/kalev_rebuild/preview.tscn`. Editable source, a normalized pre-rig sculpt, separate body regions, six fitted wearable resources, original hammer/sword, and an automated capture tool accompany it. This request does not alter live map/player scene references. The world-scale wrapper preserves the existing 2.0-unit height while source anatomy is 1.82 metres.

Skin uses the new front/back/head references. Original Blender procedural textile/leather shaders and a new ImageGen interlinked-mail plate are baked into portable albedo/normal maps. Clothes share live skeleton binding; wearable coverage is recomputed as a union when layers are removed. A distinct fitted-body ID prevents cross-equipping differently proportioned garments.

## Verification

Technical verification passed:

- Godot 4.7.1 import and all 7 fresh-character tests; the 7 shared wardrobe tests also pass. The fresh tests exercise actual pose changes, fitted-body rejection, layer coverage unions, shared skeleton binding, keyboard/gamepad paths and weapon replacement.
- Structural verification: 51,998 body triangles, 8 independently coverable body regions, 76 clips. Each shirt is 9,507 triangles; apron 3,704; hose 6,500; boots 6,850. All owned binaries stay below 10 MiB.
- Editable Blender source opens with 22 mesh objects and 15 valid relative texture paths.
- Asset provenance and repository storage validation pass; `git diff --check` passes. The active-doc report check remains red on 9 pre-existing repository issues and a stale generated report; unrelated documentation was not rewritten.
- Twenty actual Godot captures cover front, profile, back, portrait, outfits and sampled locomotion/combat poses in `docs/reports/images/kalev_rebuild/`.
- Independent agent review confirms identical garment/body inverse-bind matrices, normalized weights, valid joints, and no additional wardrobe/state blocker. It accepts this as an isolated editable study, **not production-ready visual art**.

Final body SHA-256: `c5de85fb2dc6cd35ed354f1715be25a0094852641c7015dafa9464ac7fd9a376`.

The original silhouette trim exposed long side strips. Screened Poisson reconstruction (Open3D 0.19, depth 8, scale 1.1, linear fit disabled, largest surface component, reduction to 52,000 triangles) repairs the visible side gaps. The resulting mesh is still not certified manifold production topology. Blender anatomical heat weights are solved against a temporary A-pose rig, carried through garment fitting, then transformed with geometry into the common T-pose. Generated lower hems reject arm influences. Portable skin atlases bake edge-extended sampling from the original plates; source references remain intact.

## Production limits

The Witcher 3 level of visual finish is **not achieved**. Broad projection transitions remain on the neck, profile and limbs; shoulder/neckline tailoring and hem joins need authored topology; the hands do not yet close convincingly around grips. These are visible in the captures and keep P0-214 open. This is an AI-reconstructed and fitted character study, not a finished AAA digital double. The surface still needs production retopology, a facial rig, articulated fingers/grip poses, and garment-specific cloth/secondary motion before a cinematic character can be considered complete. The character assets can be reviewed and swapped independently without changing narrative identity or gameplay state.
