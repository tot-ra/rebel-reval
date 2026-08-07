# P2-036a Wader Hunyuan3D candidate audit

## Scope

This is an optional candidate-only pass for the three standing wader species already shipped by `P2-036`:

- `grey_heron`
- `northern_lapwing`
- `common_snipe`

The local ComfyUI 0.28.2 Hunyuan3Dv2 single-image workflow was healthy after staging the three existing reference plates in ComfyUI's external input directory. Production files under `assets/birds/**` were not modified or replaced.

## Reproduction

1. Reference inputs: `generated/comfyui/bird_wader_v1/previews/*_standing.png`.
2. API-format workflow: `generated/comfyui/bird_wader_v1/candidate_workflow_api.json`.
3. Checkpoint: `hunyuan3d-dit-v2-mv_fp16.safetensors`.
4. Seeds and output mapping are recorded in `generated/comfyui/bird_wader_v1/candidate_workflow_manifest.json`.
5. Candidate meshes are in `generated/comfyui/bird_wader_v1/candidates/`.
6. Blender 5.2 import metrics and SHA-256 records are in `generated/comfyui/bird_wader_v1/candidates/candidate_audit.json`.
7. The audit is reproducible with `blender --background --factory-startup --python generated/comfyui/bird_wader_v1/audit_candidates.py`.

## Acceptance contract

Candidate acceptance requires all of the following:

- no more than 8,000 triangles;
- ground min Z within 0.02 m;
- at least one imported material/texture set;
- largest-axis ratio against the production catalog mesh in `[0.5, 1.5]`;
- a standing pose asset and authored animation coverage.

## Results

| Species | Triangles | Ground min Z | Materials | Animations | Candidate scale vs production | Verdict |
|---|---:|---:|---:|---:|---:|---|
| grey heron | 2,038 | -0.202 m | 0 | 0 | 0.358 | Reject |
| northern lapwing | 879,680 | -0.978 m | 0 | 0 | 3.542 | Reject |
| common snipe | 66,242 | -0.419 m | 0 | 0 | 1.665 | Reject |

All three outputs imported as one static mesh without materials or authored animation. Grey heron remains outside the 2 cm grounding tolerance and is undersized; northern lapwing exceeds the triangle budget by 110x, is not grounded, and is oversized; common snipe exceeds the triangle budget by 8x, is not grounded, and is oversized. None is production-ready.

## Decision

**All three candidates are rejected for production.** Keep the deterministic Blender `waders_v1` GLBs as production. Do not add candidate files to `assets/birds/**` or `assets/SOURCES.csv`. A future candidate is worth retrying only with a workflow that exports UV/material data, preserves a complete catalog-scale silhouette, grounds the mesh, includes animation coverage, and stays within the 8,000-triangle budget.
