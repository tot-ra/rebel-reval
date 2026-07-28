# Forge cat Hunyuan3D candidate v1

This directory contains the visually approved base-shape source for Kalev's smithy cat. The raw files remain staging material; the cleaned production GLB under `production/` is integrated through `assets/characters/cat/cat_rig.tscn`.

## Decision

- Visual approval: **approved as a base shape** by the user on 2026-07-23.
- Selected ComfyUI prompt ID: `7ab9a90e-d913-42b5-adb1-ffedd45cc58f`.
- Approval scope: silhouette, proportions, neutral quadruped pose, separated limbs, and tail.
- Required correction: remodel the paws during retopology. The generated paws are too rounded and cuff-like.
- The raw GLB is not production-ready: it has 187,036 triangles, 2,169 non-manifold edges, and 6 boundary edges.

## Generation contract

- One 1024 x 1024 source image.
- Exactly one cat in one neutral standing pose.
- Front three-quarter view, full silhouette in frame, uniform background, no floor or shadow.
- Local single-image Hunyuan3D workflow with exactly one `LoadImage` and `Hunyuan3Dv2Conditioning`.
- No multiview conditioning or game integration was used.

## Files

- `forge_cat_reference.png` - accepted clean source image.
- `forge_cat_reference_source.blend` and `create_reference.py` - reproducible reference source.
- `workflow_api.json` - single-image local Hunyuan3D workflow.
- `prompt_submission.json` and `generation.json` - generation provenance.
- `forge_cat_hunyuan3d_v1.glb` - approved raw base-shape candidate.
- `preview_front.png`, `preview_side.png`, `preview_back.png` - separate inspection views, not a contact sheet.
- `mesh_audit.json` and `audit_and_render.py` - reproducible topology audit and preview renderer.
- `PRODUCTION_PLAN.md` - production requirements implemented under `production/`.
- `production/forge_cat_production_v1.glb` - integrated manifold, textured, rigged runtime asset with five canonical clips.
