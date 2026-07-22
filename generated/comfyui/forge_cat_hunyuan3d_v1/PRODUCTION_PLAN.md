# Proposed forge cat production plan

The approved Hunyuan3D GLB is a shape reference, not the final game asset. Complete these steps separately and review each gate before integration.

## 1. Polygon budget

- Target LOD0: **8,000 triangles**, hard cap **12,000 triangles**.
- Target LOD1: **3,000-4,000 triangles**.
- Optional distant LOD2: **800-1,200 triangles**.

The cat is smaller on screen than the project's roughly 18,000-22,000-triangle humanoids, so this budget preserves its silhouette and deformation loops without spending humanoid-level geometry.

## 2. Retopology and decimation

- Build clean quad topology over the approved silhouette rather than using the raw 187k-triangle topology directly.
- Manually remodel all four paws with a feline paw/wrist transition and a flat, consistent ground-contact plane.
- Preserve separate leg gaps and tail clearance.
- Add deformation loops at shoulders, elbows, wrists, hips, knees, hocks, neck, jaw, and tail base.
- Produce one manifold connected character mesh with no boundary edges, hidden sheets, duplicate bodies, or floating parts.
- Use controlled decimation only for LOD1/LOD2 after the clean LOD0 topology is approved.

## 3. UV and texturing

- Use one material and one non-overlapping 0-1 UV set, with mirrored/stacked UVs only where directional fur detail is not required.
- Use a 1024 x 1024 texture set for the in-game cat; retain a 2048 x 2048 bake source if needed.
- Bake high-to-low normal and ambient occlusion maps, then author albedo and roughness for short charcoal-gray fur with restrained warm-brown forge highlights.
- Pack textures for Godot's StandardMaterial3D workflow and avoid alpha hair cards or loose whisker geometry.

## 4. Quadruped rig

- Add root, pelvis, 2-3 spine bones, chest, neck, head, optional jaw, four complete leg chains, and a 4-6 bone tail.
- Add optional ear bones only if the idle requires ear motion.
- Keep the origin centered between the paws on the ground plane, metric scale, +Y up, and Godot-compatible forward orientation.
- Validate weights at shoulders, hips, paws, neck, and tail base with no collapsing volume or sliding feet.

## 5. Idle animation

- Create one 4-6 second seamless `idle` loop at 30 fps.
- Include subtle breathing, a small head/ear reaction, and restrained tail motion suitable for a calm observant smithy cat.
- Keep the root stationary and all four paws locked to the ground. Avoid large movement until a separate walk animation is requested.

## 6. GLB and Godot verification

- Export a separate production GLB with mesh, armature, one material, and `idle` animation.
- Verify scale, origin, forward axis, ground contact, normals/tangents, texture color space, skeleton import, animation looping, and bounding box in Godot.
- Test under the forge camera and lighting, including the interaction distance and collision footprint.
- Confirm the GLB imports without errors and stays within the polygon/texture budgets before replacing any existing cat rig reference.
