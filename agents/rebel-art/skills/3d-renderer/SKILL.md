---
name: 3d-renderer
description: Generate, inspect, approve, and prepare clean 3D assets with local ComfyUI while keeping raw candidates out of the game until production approval.
---

# ComfyUI 3D Asset Generation

## Goal

Generate and visually approve one clean base shape before spending time on topology, texturing, rigging, animation, or game integration. Treat the raw Hunyuan3D mesh as a shape candidate, not as a production asset.

## Non-negotiable input rules

1. Use an image containing **exactly one object in one pose and one view**.
2. Never use a contact sheet, collage, split image, turnaround, or image containing multiple views.
3. Keep the whole object visible with generous empty space around the silhouette. Aim for at least 10% clear margin on every edge.
4. Use a plain, uniform background with no floor line, shadows, text, props, scenery, or pedestal.
5. For characters that will be animated, use a neutral riggable pose:
   - quadruped: standing on four legs, all paws visible, legs and tail clearly separated;
   - humanoid: relaxed A-pose with visible hands and feet.
6. Prefer a clean front three-quarter view for the first generation.
7. Use multiview only when the user explicitly requests it and each view is a separate, consistent file. Default to single-image generation.

## Efficient workflow

### 1. Preflight once, in parallel

Before generating anything:

- read the character/location brief and identify the gameplay camera, scale, and style;
- inspect existing comparable assets to estimate later polygon and texture budgets;
- check Git status and create a dedicated staging directory outside game `assets/` and `scenes/`;
- confirm local ComfyUI health, the Hunyuan3D checkpoint, required nodes, input/output paths, and Blender availability;
- verify that the selected image provider is configured before calling it;
- reuse an existing API-format workflow only after confirming its ownership and inputs.

Do not modify unrelated untracked artifacts. Keep all candidate files under one clearly named staging directory.

### 2. Create one reference, with a bounded retry policy

Prefer the most controllable source method available:

1. an already approved clean concept;
2. a reproducible Blender/procedural reference for strict pose and silhouette requirements;
3. a local image model for stylistic concepts.

For a generative image model, request exactly one image. Allow at most **two prompt retries** for duplicate subjects, cropping, hidden limbs, or background contamination. If it still fails, switch to a deterministic Blender/procedural reference instead of continuing random retries.

The procedural reference is only a source image. Do not export or integrate its geometry as the requested game model.

### 3. Run a reference QA gate before Hunyuan3D

Visually inspect the final RGB image. Do not infer visual quality from the prompt or source scene alone.

Required checks:

- exactly one subject;
- one neutral pose and one view;
- complete silhouette inside the frame;
- correct anatomy with no extra, missing, crossed, or merged limbs;
- required extremities and tail are visible and separated;
- uniform background with no floor, shadow, prop, text, or scenery.

Add cheap programmatic checks where useful:

- image dimensions and color mode;
- foreground bounding box and edge margins;
- border uniformity;
- visible-limb mask audit for riggable characters.

Programmatic checks support visual review but do not replace it. A separated tail or limb may legitimately appear as a separate 2D silhouette component.

If no reliable visual preview is available, do not claim that the reference passed. Use another preview path or ask the user to review it.

### 4. Validate the workflow structure before the expensive run

For the default single-image Hunyuan3D workflow, assert:

- exactly one `LoadImage` node;
- one `Hunyuan3Dv2Conditioning` node;
- no `Hunyuan3Dv2ConditioningMultiView` node;
- no left, right, or back image inputs;
- one output GLB;
- fixed seed and recorded sampler settings.

Copy the accepted reference into the configured ComfyUI input directory, submit once, and record the prompt ID immediately. Poll by prompt ID rather than resubmitting when a long local run is still active.

### 5. Inspect the raw candidate without repairing it

Preserve the raw GLB unchanged and record its SHA-256. In parallel when possible:

- import it into Blender;
- render **three separate files**: front, side, and back;
- confirm the head/body axis before labeling the views;
- record mesh/object count, connected components, dimensions, triangles, loose geometry, boundary edges, and non-manifold edges;
- for quadrupeds, verify four separate lower-leg/paw regions and clear gaps between limbs;
- inspect the tail, underside, ears, and ground-contact areas from useful oblique angles if the orthographic views are ambiguous.

Do not combine the three views into a contact sheet unless the user separately asks for one after generation.

## Candidate decision gates

### Hard rejection: regenerate the base shape

Reject the candidate when front/side/back inspection shows a fundamental shape failure:

- duplicate bodies or duplicate major parts;
- a sheet, wall, billboard, or collapsed depth;
- fused or missing limbs that destroy the riggable silhouette;
- floating/disconnected geometry that is not intentional;
- severe holes that remove recognizable anatomy;
- fundamentally wrong proportions, pose, or object identity.

Do not repair a fundamentally bad generation.

### Conditional base-shape approval: keep for production cleanup

Do **not** automatically discard an otherwise good silhouette only because the raw generated topology has:

- excessive polygon count;
- non-manifold edges or small boundary defects;
- noisy tessellation or normals;
- rough paws, fingers, ears, or other local forms that can be deliberately remodeled;
- missing UVs, textures, skeleton, or animation.

Record these as mandatory production defects. Ask the user to approve or reject the **base shape**, explicitly naming the defects and the prompt ID. User approval may cover silhouette/proportions while requiring local anatomy changes during retopology.

Once the user selects a candidate, stop alternate generation or mesher experiments unless they ask for them. Preserve the selected prompt ID and do not silently substitute another GLB.

## Approval and integration boundary

Before approval, keep the candidate only in staging. Do not:

- copy it into game asset paths;
- replace an existing rig or scene reference;
- edit gameplay scenes, collisions, or content records;
- present the raw Hunyuan GLB as game-ready.

After approval, document:

- selected prompt ID and GLB checksum;
- approval scope;
- visible defects to fix;
- whether integration has occurred, which should remain `false` until the production GLB passes Godot verification.

Then propose the production steps separately. Execute them only when requested.

## Post-approval production proposal

Derive budgets from comparable project assets and expected screen size, then propose:

1. LOD0 polygon target and hard cap, plus optional LOD1/LOD2;
2. retopology strategy and local anatomy remodeling before decimation;
3. manifold cleanup, normals, origin, scale, forward axis, and ground contact;
4. UV layout, texture resolution, materials, and high-to-low bakes;
5. skeleton hierarchy and skin-weight checks;
6. a minimal looping `idle`, with locked feet/paws;
7. separate production GLB export and in-engine verification.

For deforming characters, prefer clean retopology for LOD0. Use controlled decimation primarily for lower LODs, not as a substitute for animation-ready topology.

## Game-ready checks

- One connected character mesh unless separation is intentional.
- No duplicate bodies, hidden planes, loose parts, floating geometry, or unintended holes.
- Manifold production topology and a polygon count within the approved budget.
- Clean silhouette from every gameplay camera angle.
- Correct metric scale, origin, forward axis, and ground contact.
- Valid UVs, normals/tangents, texture color space, and Godot-compatible materials.
- Rig deforms cleanly at shoulders, hips, paws/hands, neck, and tail.
- At minimum, test a looping `idle`; add `walk` only if movement is required.
- Verify the final GLB in Godot under the target scene camera and lighting, not only in Blender or ComfyUI.

## Output hygiene

Keep only the accepted reference, selected raw GLB, separate previews, reproducible workflow/settings, QA report, approval decision, and production proposal. Delete session-created rejected retries unless the user asks to retain comparisons. Never delete or commit unrelated existing worktree files.

## Default decision

When unsure, make **one controllable reference, run one single-image workflow, and ask for one base-shape decision**. A simple approved shape with documented production defects is more useful than repeated expensive generations or an unapproved raw mesh integrated into the game.
