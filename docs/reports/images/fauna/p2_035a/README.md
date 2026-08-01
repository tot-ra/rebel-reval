# P2-035a Waterfowl Hunyuan3D candidate audit

## Scope

This is a candidate-only pass for the four standing waterfowl species already shipped by `P2-035`:

- `mute_swan`
- `mallard`
- `greylag_goose`
- `great_cormorant`

The local ComfyUI 0.28.2 Hunyuan3Dv2 workflow was healthy after staging the input references in ComfyUI's external input directory. Production files under `assets/birds/**` were not modified or replaced.

## Reproduction

1. Reference inputs: `generated/comfyui/bird_waterfowl_v1/previews/*_standing.png`.
2. Workflow template: `generated/comfyui/medieval_animals_v1/workflow_api.json`.
3. Checkpoint: `hunyuan3d-dit-v2-mv_fp16.safetensors`.
4. Seeds and output mapping are recorded in `generated/comfyui/bird_waterfowl_v1/candidate_workflow.json`.
5. Candidate meshes are in `generated/comfyui/bird_waterfowl_v1/candidates/`.
6. Blender 5.2 import metrics and SHA-256 records are in `generated/comfyui/bird_waterfowl_v1/candidates/candidate_audit.json`.
7. Visual comparison: `p2_035a_waterfowl_candidate_contact_sheet.png` and the individual plates in this directory.

## Results

| Species | Triangles | Ground min Z | Materials | Candidate scale vs production | Verdict |
|---|---:|---:|---:|---:|---|
| mute swan | 17,374 | -0.977 m | 0 | 0.384 | Reject |
| mallard | 40,772 | -0.482 m | 0 | 0.790 | Reject |
| greylag goose | 87,376 | -0.870 m | 0 | 1.068 | Reject |
| great cormorant | 634 | -0.091 m | 0 | 0.282 | Reject |

All four outputs imported as one mesh and contain no authored animation. The standing pose is therefore only a static generated mesh, not a production-ready animation deliverable. The first three exceed the 8,000-triangle fauna budget. All four lack materials/textures and fail the 2 cm grounding tolerance. The cormorant is small/incomplete relative to the production silhouette and fails visual review despite passing the triangle count.

## Decision

**All four candidates are rejected for production.** Keep the deterministic Blender `waterfowl_v1` GLBs as production. Do not add candidate files to `assets/birds/**` or `assets/SOURCES.csv`. A future candidate is worth retrying only with a workflow that exports UV/material data, preserves a complete catalog-scale silhouette, grounds the mesh, and stays within the 8,000-triangle budget.
