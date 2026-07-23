# Hunyuan3D cat generation

This directory contains a locally generated Hunyuan3D cat mesh and its source images.

## Files

- `cat_hunyuan3d_local.glb` - generated 3D mesh.
- `cat_preview.png` - Blender clay render for quick inspection. The orange material is only used by the preview and is not embedded in the GLB.
- `cat_front.png` and `cat_back.png` - front and back reference images supplied to Hunyuan3D.
- `workflow_api.json` - reproducible ComfyUI API-format workflow.

## Generation settings

- ComfyUI checkpoint: `hunyuan3d-dit-v2-mv_fp16.safetensors`
- Seed: `724031`
- Steps: `20`
- CFG: `7.5`
- Sampler: `euler`
- Scheduler: `normal`
- Latent resolution: `3072`
- Octree resolution: `256`
- Mesh algorithm: `surface net`
- Mesh threshold: `0.6`
- ComfyUI prompt ID: `512fb3cd-530f-48a1-8b2d-97f086387e16`
- Runtime: `00:10:39` on Apple MPS

## Validation

The GLB was imported successfully with Blender 5.2.0 LTS. It contains one untextured mesh with 384,815 vertices and 1,092,708 triangles. SHA-256:

`2027ef0dd7a74ae865aa40b2cf0c2d39819e4ebe34d9389c1b75b2572c1dde66`

The original requested workflow uses the cloud-backed `TencentImageToModelNode` and requires a logged-in ComfyUI account. The local workflow above was used instead because the local Hunyuan3D multiview checkpoint was already installed.
