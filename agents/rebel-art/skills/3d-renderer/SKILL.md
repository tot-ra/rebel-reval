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

### Creature realism gate

For pigs, sheep, cattle, horses, dogs, and other animals, target **anatomical and husbandry realism inside the binding non-photoreal art direction**. Realism means a species-correct silhouette, believable skeletal landmarks and weight distribution, plausible age/body condition, historically appropriate phenotype and tack, and restrained coat materials. It does not mean photoreal shaders, dense strand fur, or modern show-breed exaggeration.

Add `species`, `sex_age`, `use`, `phenotype`, `anatomy_reference`, and `pose` to the compact brief. For a historical setting, source the regional period phenotype; when evidence is incomplete, describe a generic unimproved landrace and record the assumption instead of inventing a named breed. Base dimensions on withers/shoulder height and nose-to-rump length, not on a generated mesh's bounds.

Use this reference pattern, replacing the bracketed fields:

```text
full-body anatomically credible [species, sex/age, use], [sourced regional-period phenotype], natural body condition, species-correct head-to-body ratio and leg joints, weight evenly supported in a neutral square stance, all four legs and feet clearly visible and separated, tail and ears clear of the body, restrained natural coat variation, realistic form adapted to the approved game art direction, eye-level front three-quarter view, even soft lighting, isolated on a uniform mid-gray background, 10% margin; no ground, cast shadow, scenery, text, extra limbs, merged legs, oversized head or eyes, inflated torso, peg legs, fantasy features, modern show-breed exaggeration, dramatic pose, or accessories not named in the brief
```

Use species-specific cues without replacing a sourced anatomy reference:

| Animal | Minimum silhouette/anatomy cues |
|---|---|
| Pig | Low long torso, wedge-shaped head and mobile snout, short correctly articulated legs, cloven hooves; no generic wild-boar tusks or ridge unless sourced. |
| Sheep | Narrow muzzle, distinct neck/chest under the fleece, visible lower legs, cloven hooves; fleece follows the body instead of forming a spherical cloud. |
| Horse | Defined withers and sloped shoulder, deep ribcage, readable knees/hocks/fetlocks, one hoof per leg; use a sourced medieval riding, cart, or pack type rather than a modern sport/show breed. |
| Cattle | Long load-bearing torso, distinct shoulder/pelvis and plausible dewlap, cloven hooves, age/sex-appropriate horns and udder or sheath only when specified. |

Generate the base animal without equipment by default. Model harness, packs, blankets, collars, and similar tack as separate geometry when required, so anatomy remains reviewable and the animal stays reusable. For quadrupeds, reject the 2D reference before 3D generation unless:

- the spine, shoulder, pelvis, chest, and belly read as one plausible load-bearing body;
- all four limbs have species-correct joint direction and reach the same ground plane;
- feet are distinct and correct for the species, including cloven hooves for pigs/sheep/cattle and single hooves for horses;
- muzzle, eyes, ears, horns/tusks when applicable, and tail have plausible placement and scale;
- the silhouette remains recognizable without coat color or texture detail.

Use the single allowed visual approval on this reference before the expensive 3D run when anatomy or historical phenotype is uncertain. A clean background cannot compensate for an anatomically weak source.

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

For animals, audit shape before topology cleanup. Compare orthographic front/side/back renders against the brief's anatomy reference and record `anatomy_decision`, `scale_basis`, and short defect codes in `report.json`. Reject rather than repair when the candidate has incorrect limb count or joint direction, fused weight-bearing legs, malformed feet/hooves, implausible head/torso proportions, broken spine or chest volume, or equipment fused into the body. Retopology and decimation can preserve good anatomy, but they do not turn a malformed reconstruction into a realistic animal.

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
- animal anatomy review against the approved reference at front/side/back views, including feet, joint bends, ground contact, body proportions, and equipment separation;
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
