# Art playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Art role.

## Role-specific lessons

### Capture and tooling
- Headless dummy rendering cannot read a SubViewport texture. Use the Metal driver and verify PNG header and dimensions.
- Host Blender 5.2 exposes EEVEE as `BLENDER_EEVEE`, not `BLENDER_EEVEE_NEXT`. Factory-startup may leave `scene.world` unset; create an explicit world before writing world color.
- Blender's bundled Python often lacks Pillow. Compose contact sheets with host `python3` after Blender writes per-species previews.
- `blender_run_script` may not mount the project at `/workspace`. Pass absolute GLB paths to `bpy.ops.import_scene.gltf`.
- Blender `mathutils.Vector` uses `(a - b).length`. Flatten matrix rows before scalar comparison. `bpy_prop_collection` does not support non-unit slices.
- Blender-authored generators import `bpy`. Invoke them through Blender, not repository `python3`.
- When Leonardo, ComfyUI, or Hunyuan3D is unavailable, ship deterministic Blender generators instead of blocking. Leonardo may reject an unsupported `preset_style`; retry with the field empty.
- Cursor CLI does not expose `leonardo_generate_image`. Call Leonardo REST through `tools/generate_leonardo_material.py` and store the full prompt in `prompt.json` beside the plate. The CDN returns 403 to bare urllib; send a browser User-Agent.
- Do not downscale authored grass or mud into the 128 px terrain array. Sample those plates at native 512 px. The shared array stays small so procedural families do not pay a 16x paint cost.
- City walls need coursed limestone rubble, not the even ashlar `stone` family. Keep the generation prompt with the plate so the next pass can sharpen joints instead of guessing.
- Do not half-tile-offset a coursed masonry plate before welding. That move puts the original wrap seam across the middle of the wall face.
- Extra house wall/roof maps belong in `assets/materials/pbr/building_variants/` from `tools/generate_building_surface_variants.py`. Do not mutate imported GLB materials; duplicate onto surface overrides keyed by stable building id.
- Never open `assets/SOURCES.csv` with mode `w` until the replacement row list is fully built. Prefer write-to-temp then rename. Parse with `csv.DictReader`. The primary key is `asset_id`; SHA-256 belongs in `prompt_or_url`.
- After adding fauna or prop GLBs, run a headless Godot import before tests. Update bird authored-mesh allowlists in the same change as new `assets/birds/**` GLBs.
- Verification-only captures can overwrite tracked evidence PNGs. Check `git status` immediately and restore pre-existing outputs before committing.
- When retiring a duplicate character body, search both catalogue and live-integration tests: the live rig may already use a differently named replacement and its own wardrobe. Update tests to assert the active body, and do not recreate deleted fitted gear just to satisfy stale assertions.
- When cleaning generated assets, remove only the exact newly created paths. A broad glob can delete another worker's artifacts.
- Batch runtime GLB cleanup uses `tools/assets/cleanup_runtime_glb.py` after a JSON-chunk audit (`tools/assets/glb_runtime_audit.py`). Blender's glTF importer can fabricate a phantom `Icosphere` that is not in the file; do not re-export those. Decide helpers from node/object names, not mesh datablock names: songbird `Leg_L` keeps data named `Cylinder`, and KayKit cape/shield keep `Plane.NNN` / `Cylinder.NNN`. Treat `Icosphere`/`Camera`/`Light` (any suffix) and only exact unused `Cube`/`Plane`/`Cylinder` objects as helpers. After a real helper is removed, snap livestock/fauna to Z=0; do not independently snap shared-rig character LOD GLBs, because `SharedCharacterRig` remounts those meshes onto the live skeleton. Verify helpers from the GLB JSON chunk or Godot ground-contact tests, not a Blender re-import.

### Diagnosing a rendering artifact
- Identify the offending surface before editing anything. Three debug renders answer almost every "what is that?" question, and each costs one capture run: replace `ALBEDO` with a constant (artifact gone means it is albedo, not lighting or geometry), enable `Viewport.DEBUG_DRAW_WIREFRAME` (shows whether the shape is one mesh, a decal quad, or a MultiMesh), and write the suspect values into `EMISSION` channels with `ALBEDO = vec3(0.0)` so a script can sample exact values from the PNG.
- Do not confirm a suspect material by setting its albedo uniform to magenta. A transparent overlay that derives its colour from `EMISSION` or from a screen sample ignores albedo entirely and stays innocent-looking. Force `EMISSION` instead.
- Hard-edged triangular wedges in ground or terrain are a `flat` varying, not a texture. Layer indices that are flat per triangle while the blend weight interpolates make the provoking vertex paint the whole triangle; no fragment-side noise, contrast or tone change can remove them.
- A node dump that walks `MapView3D` children misses terrain and scatter: chunks are built on demand and are not in the tree until the viewport has rendered. Dump from inside the capture tool after the warm-up frames, and handle `MultiMeshInstance3D` separately from `MeshInstance3D`.
- `hint_screen_texture` is unreliable for transparent decals under the shipped GL Compatibility renderer; it returned white and turned puddles into pale shards. Prefer a darkening film plus fresnel sheen, which is also cheaper than a per-decal back-buffer copy.

### Material scale
- Derive tiling from the physical size of the thing, not from what looks busy. One world unit is about 0.87 m, so a limestone rubble course is about 0.3 m and a brick course about 0.1 m. The masonry repeats before P0-218 packed roughly six times that many courses into a wall, which is exactly what makes stone read as printed wallpaper.
- Flat surfaces without a normal map are the main reason large architecture looks like painted cardboard. `Image.bump_map_to_normal_map()` on the same grayscale plate that produced the albedo is enough, and its cache key must include the plate seed and size.
- An authored RGB plate excluded from palette tinting will drift out of the value range of everything it borders. Either tint it or check its lit value against its neighbours.

### Character skin projection
- Per-face front/back material switches on a single mesh leave a torn silhouette seam and smear reference plates across every side-facing surface, because planar XZ projection collapses texel density wherever the normal turns away from the camera. Bake one smart-projected atlas instead: blend the original plates per texel by a cubed facing term, diffuse low-confidence grazing texels, and retire the old projection sidecars in the same change as the GLB rebuild.
- Locomotion that only keys hips and a flat shoulder swing reads as a mannequin slide. Conjugate lower-arm rotations through each shoulder's rest drop so elbow keys hinge correctly, and ground each cycle with sole probes plus a pelvis offset so the lowest heel/ball/toe contact stays on the floor.
- Diffusing a texture fill across an unwrapped atlas in UV space cannot work: islands are packed arbitrarily, so a texel's neighbour may be hair, an unrelated limb or background, and relaxation that averages uncovered texels drags island borders to black. Bin by world position and weight every contribution by the facing term instead.
- Which arm folds matters. In a run the lead arm closes toward the chest and the trailing arm opens behind the hip; fold them the other way and both hands park in front, which `test_character_rig` catches as a contralateral-swing failure.
- Ankle and toe rotation ride the same sine as the hip, not a quarter-cycle cosine. On a cosine the foot is neutral at both heel strike and toe-off and points through mid-stance, so the character walks on its toes. Render the cycle over a floor plane; foot contact is not judgeable against empty background.
- Do not run a blanket `vertex_group_smooth` over a heat bind on a clavicle-less skeleton. It spreads chest weight onto upperarm and back, `bind()` then keeps only the four largest influences, and the shoulder tears open along a hard crease. Judge such a change by rendering an unchanged CC0 clip before and after, and by the mean pixel delta, not by eye.

### Materials, export, and provenance
- Blender glTF export with packed textures still yields Godot-extracted albedo, normal, and roughness sidecars. Register those derived paths.
- A material created via `bpy.data.materials.new()` has `use_nodes = False`. The exporter then writes default grey. Untextured materials still need Principled BSDF.
- Vertex colours reach Godot only through COLOR_0. Export all sets and promote the real set after export. Verify on the Godot side (`ARRAY_COLOR` plus `vertex_color_use_as_albedo`). Do not assign a surface-override material for headless livestock tests; the dummy renderer reports that override as null.
- Character glow under MapView bloom is usually ORM roughness G=0 or `KHR_materials_unlit`. Repair with `tools/repair_character_orm_normals.py`. Sketchfab game-ready coats often ship unlit.
- Smart-projected livestock UVs plus a Cycles emit bake can turn horns, udder, and mane into a dot grid. Paint those regions as COLOR_0.
- A material name missing from the generator palette silently falls back to `outerwear`. Add palette, roughness, and specular entries with the geometry.
- Do not delete Godot-extracted character PNGs until GLB images are URI-linked. After the switch, tests must match `hero_tex_` shared stems.
- Rights-blocked media: preserve the verified fallback. Never download or register an asset from metadata or a CC BY-NC page alone.

### Anatomy and generators
- Shared quadruped livestock GLBs face -X. Fix `MODEL_YAW` before rebuilding `dimensions_m`. Measure world height through the actor host transform, not the raw mesh AABB.
- Joined procedural volumes without voxel remesh ship as a bubble cloud. Remesh and unify-smooth before rigging. Start legs inside the barrel. Keep ears inside the skull height budget.
- Facial detail spheres must snap to the remeshed surface. Claws and eyes authored in pre-normalize world space float after `normalize_dimensions`.
- Palmate antlers remeshed with the hull fuse into the scapular hump. Keep body-only remesh and parent palms as detail meshes.
- Sparse sphere tails remesh into beads. Keep a continuous overlapping spine. Measure coat `side_ratio` from body-only width.
- `create_quadruped_rig` places pupils 1.5 cm in front of the socket. Author small-skull eyes manually.
- Do not sit catalog scapular cards proud of a bird hull. Do not add an 11th argument to `curve_tube`; gdlint caps functions at 10 arguments.
- Bone-level proportion changes shift `BODY_STATURE`. Update `SharedCharacterRig.HEROIC_MODEL_SCALE` to `2.0 / BODY_STATURE` and regenerate LODs.
- Iterate character pose work on the skeleton intermediate plus a numeric audit. Only run the full body rebuild once the numbers land.
- Indoor wall banners hang from a wall-parallel top rod with UV.y hem sway. Banner cloth authored in XY with a -Z lit face needs `rotation.y = +PI/2`.
