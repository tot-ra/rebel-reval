---
name: 3d-renderer
description: Generate clean 3D assets with ComfyUI and prepare them for game use.
---

# ComfyUI 3D Asset Generation

## Goal

Generate one clean 3D object first. Optimize, texture, rig, and animate it only after the base shape passes visual inspection.

## Input rules

1. Use an image containing **exactly one object in one pose**.
2. Never use a contact sheet, collage, split image, or image containing multiple views.
3. Keep the whole object visible with empty space around its silhouette.
4. Use a plain, uniform background with no floor, shadows, text, props, or scenery.
5. For characters that will be animated, use a neutral riggable pose:
   - quadruped: standing on four legs, legs and tail clearly separated;
   - humanoid: relaxed A-pose with visible hands and feet.
6. Prefer a clean front three-quarter view for the first generation.
7. Use multiview only when each view is a separate file and all views show the same object, pose, proportions, scale, and framing. If consistency is uncertain, use one image.

## Workflow

1. Generate or obtain the source image.
2. Inspect it before running 3D generation. Reject it if there are extra objects, merged limbs, cropped parts, inconsistent anatomy, or background artifacts.
3. Run a single-image Hunyuan3D workflow first.
4. Render the generated mesh from front, side, and back.
5. Reject and regenerate if the mesh contains duplicate bodies, sheets/walls, floating parts, holes, or fused limbs. Do not repair a fundamentally bad generation.
6. When the shape is approved, create the game-ready asset in separate steps:
   - remove disconnected geometry;
   - retopologize or decimate to the project polygon budget;
   - fix normals and UVs;
   - bake textures and normal maps;
   - add a skeleton and skin weights;
   - create and test animations;
   - export GLB and verify it in Godot.

## Game-ready checks

- One connected character mesh, unless separation is intentional.
- Clean silhouette from every gameplay camera angle.
- No hidden planes, duplicate bodies, or floating geometry.
- Polygon count matches the target platform and screen size.
- Correct scale, origin, forward axis, and ground contact.
- Rig deforms cleanly at shoulders, hips, paws, neck, and tail.
- At minimum, test `idle`; add `walk` only if the character moves.
- Verify the final GLB in-engine, not only in Blender or ComfyUI.

## Default decision

When unsure, generate **one object from one clean image in one neutral pose**. A simple correct mesh is more useful than a detailed broken mesh.
