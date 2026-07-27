---
name: 3d-renderer
description: Produce game-ready 3D assets through a token-efficient deterministic Blender or image-to-3D workflow while keeping raw generated candidates out of runtime paths.
---

# Token-efficient 3D production

## Objective

Produce one verified asset with the fewest LLM decisions, context reads, and generation attempts. Spend compute in scripts and tools, not model context. Raw image-to-3D meshes are shape candidates, never shipped assets.

## Token budget rules

1. Route once, generate once, and use at most two controlled retries.
2. Keep the active text packet - brief, state, and latest metrics - under roughly 2 KB.
3. Never paste workflow JSON, GLB data, vertex dumps, or full Blender/Godot logs into context.
4. Write complete evidence to files. Return only exit status, compact metrics, and filtered failures.
5. Cache immutable stages by hashes. Resume from `state.json`, not chat history.
6. Ask for one visual approval only when human judgment is required.
7. Final responses contain paths, hashes, metrics, checks, and unresolved defects only.

## 1. Compact brief and route

Read only the binding art rules, relevant asset/location brief, one comparable asset, and target scene. Save decisions once in a `brief.json` of at most 20 lines:

```json
{"id":"prop.smithy_chair","kind":"rigid_prop","target":"res://assets/props/furniture/smithy_chair.glb","scene":"res://scenes/reval_east/forge/forge.tscn","dimensions_m":[0.56,1.05,0.52],"triangles":{"target":2000,"max":3000},"textures":{"albedo":512},"style_refs":["docs/ART_BIBLE.md","docs/MATERIAL_STYLE_LOCK_KIT.md"],"approval":"task-authorized"}
```

Reference this path instead of repeating the brief.

| Asset | Route | Skip |
|---|---|---|
| Furniture, tools, crates, signs, simple architecture | Parameterized Blender generator | Concept image and image-to-3D |
| Organic creature, statue, irregular hero prop | One reference -> image-to-3D -> Blender cleanup | Primitive approximation |
| Acceptable existing mesh | Blender cleanup/conversion | New image and generation |

Known rigid dimensions favor Blender: it is exact, deterministic, fast, and cheaper than discussing and repairing a noisy AI mesh.

## 2. Batched preflight and cache

In one batched tool call, check only owned/exact paths:

- scoped Git status and target prop ID;
- Blender version;
- ComfyUI health only for image-to-3D;
- hashes of brief, input/source, generator/workflow, and cached output;
- dimensions and triangle/material count of one comparable asset.

Search first, then use bounded reads. Do not rescan the repository. Redirect verbose command output to files and return only filtered error lines.

Cache key:

```text
sha256(brief + input/source + generator/workflow + model version + seed + settings)
```

If `state.json` has this key and output checksums match, skip generation and verify the cache.

## 3A. Deterministic Blender route

Use one Python generator that emits a production GLB, optional single preview, compact `report.json`, and one stdout line under 500 characters:

```text
ASSET_METRICS={"triangles":2332,"materials":3,"uv_sets":1,"dimensions_m":[0.555,1.0525,0.521],"ground_min":0.0,"sha256":"..."}
```

Requirements:

- metric size, Y-up GLB, stable root, ground contact at zero;
- few meshes/materials, UVs, and portable glTF PBR materials;
- baked/generated textures because arbitrary Blender shader nodes do not export;
- fixed parameters and deterministic texture generation;
- final rebuild has the same SHA-256.

Do not save `.blend` when the script fully reproduces the result. Give Blender geometric rules, not model-authored vertex arrays.

## 3B. Image-to-3D route

### Reference

Use one object, pose, and view on a uniform background, with 10% margins and no floor, shadow, text, scenery, or pedestal. Animated subjects use a neutral separated-limb pose. Default to a front three-quarter view. Generate one image; retry at most twice for cropping, duplication, merged anatomy, or background contamination, then switch source method.

### Workflow

Store verified API workflows as versioned files. Call `comfyui_run_workflow` with `workflow_path` and small `input_overrides`; never inline the full workflow JSON in tool calls or chat.

Validate workflow files by script and print only:

```json
{"load_images":1,"conditioning":"Hunyuan3Dv2Conditioning","multiview":false,"outputs":["glb"],"seed":382182111,"valid":true}
```

Local single-image Hunyuan requires one `LoadImage`, one `Hunyuan3Dv2Conditioning`, no multiview/side/back inputs, one GLB output, and a fixed seed. Workflows with `TencentImageToModelNode`, multiple loaders, optional views, or randomized seeds must be labeled as their actual provider.

Submit once, store the job ID immediately, and poll it. Never resubmit a slow run. Poll messages contain only status, elapsed time, and terminal paths.

## 4. Scripted audit and decision

Preserve and hash raw generated GLBs. A Blender/Python audit writes details to `report.json` and prints one compact record:

```json
{"meshes":1,"components":1,"triangles":187432,"boundary_edges":6,"non_manifold_edges":2169,"dimensions_m":[0.52,0.37,0.17],"uv_sets":0,"decision":"cleanup"}
```

Use image previews, not verbose textual descriptions. Rigid props need one three-quarter preview and one in-engine frame. Organic/rigged candidates need separate front, side, and back views.

Reject duplicate bodies, collapsed depth, fused/missing major parts, floating geometry, severe holes, or wrong identity/proportions. High polygon count, noisy topology, small manifold defects, and missing UV/rig are cleanup defects if the silhouette is good.

## 5. Persist minimal state

Keep `state.json` next to staging output:

```json
{"asset_id":"creature.forge_cat","route":"image_to_3d","stage":"candidate_approved","cache_key":"...","job_id":"...","selected_glb":"candidate.glb","sha256":"...","decision":"cleanup","defects":["non_manifold","no_uv","no_rig"]}
```

Stages: `briefed`, `reference_ready`, `generating`, `candidate_ready`, `candidate_approved`, `production_ready`, `integrated`, `rejected`. Keep detailed measurements only in `report.json`; state uses short defect codes.

## 6. Cleanup and integration

After candidate approval, create a separate production GLB. For deforming characters use deliberate LOD0 retopology, clean skeleton/weights, and a minimal looping idle; decimate mainly lower LODs.

Scripted verification must cover:

- component/mesh count and no duplicate/floating geometry;
- polygon cap, normals/tangents, UVs, and portable materials;
- metric scale, axes, origin, and ground contact;
- rig deformation/idle when applicable;
- clean Godot import and one target-scene render;
- unchanged gameplay collision/navigation unless explicitly authorized.

Keep generated candidates outside runtime paths before approval. Record tool/workflow version, seed if used, checksum, edits, rights, and approval in `assets/SOURCES.csv`.

## 7. Minimal final report

```text
Route: deterministic_blender | image_to_3d
Asset: <path> | Reproduce: <one command>
Metrics: <triangles>; <materials>; <dimensions>; <textures>
Hashes: <cache key>; <final GLB SHA-256>
Verified: <lint>; <Godot import/test>; <in-scene preview>
Decision: integrated | approval needed | rejected
Defects/blockers: <short list>
```

Point to prompts, workflow files, reports, and logs instead of quoting them. When unsure, make one controllable reference or deterministic build, run one workflow, and request one decision.
