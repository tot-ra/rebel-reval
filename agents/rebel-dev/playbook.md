# Dev playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Dev role.

## Role-specific lessons

### Godot 4.7 contracts
- Godot 4.7 rejects `name = value` inside call sites as assignment-in-expression. Use positional args.
- Typed inference fails on `for side in [-1.0, 1.0]`. Declare `for side: float in [...]`. Values from `Dictionary.get()`, untyped arrays, `pop_front()`, and `Node.get_class()` often need an explicit `Variant` / typed local under warnings-as-errors.
- `DialogueSettings.default_settings()` is untyped. Assign it to an explicit `Variant` before reading fields.
- Shader sampler types are case-sensitive (`sampler2D`, not `sampler2d`).
- `Dictionary.merged()` is not a constant expression. Shard merges need a lazy static cache, not `const PROFILES = base.merged(shard)`.
- Do not `preload("res://some/dir/")` a directory. Do not call `has_method()` on preloaded Script classes in contract tests.
- In RefCounted test scripts, use `(Engine.get_main_loop() as SceneTree).root`, not `get_tree()`.
- `%` treats an Array RHS as the placeholder argument list. Format one `%s` with `str(value)`.
- `CONFUSABLE_LOCAL_DECLARATION`: rename the narrower-scope variable. A navigation probe can also fail when a loop iterator is redeclared in the same scope.
- Keep `.gdlintrc` `class-definitions-order` aligned with gdtoolkit defaults (`signals`, `enums`, then `consts`).
- Hard-to-wrap `max-line-length` lines can use `# gdlint: ignore=max-line-length` on the previous line. Do not insert a one-method regression into a large legacy `test_*.gd` that already exceeds the cap; put it in its own file.
- Do not silence unused-arg warnings by renaming `setup` parameters to match member fields. That shadows members and can leave them null.

### Harness, import, and capture
- On-commit Godot resolution should honor `GODOT_BIN`, then `godot` on PATH, then `/Applications/Godot.app/Contents/MacOS/Godot`.
- After adding a `class_name` or new GLB, run a headless import before tests. `ResourceLoader.exists` stays false until `.import` sidecars exist.
- `verify_clean_checkout_load.sh` must reject a missing `GODOT_BIN` before `git worktree add`.
- Headless SubViewport captures hit the dummy renderer. Use Metal for PNG evidence. Do not pipe the checked runner through `tail` while it is still running.
- Headless DisplayServer has no pasteboard. `clipboard_get` emits ERROR and fails the harness. Guard `clipboard_set` with `DisplayServer.has_feature(FEATURE_CLIPBOARD)` and assert the composed text, not the OS clipboard.
- ADR 0018 day/night plates need one Godot process per plate. Add `Camera3D` to the tree before `look_at()`.
- Temporary Godot probes must live under `res://`, call `quit()` on SceneTree (not `get_tree()`), and use `Input.parse_input_event`. Keep them until every planned rerun is done.
- Godot 4.7 headless dummy renderer does not round-trip `MultiMesh.get_instance_transform()` after `set_instance_transform()`. Assert authored transforms before commit.
- When a Godot preload cannot resolve an existing script, run that script directly to expose the first parse error. After clearing it, rerun immediately: dependent compile and shader defects only surface once the first error is gone.
- Runtime-built UI cannot use `%UniqueName` until `owner` is an ancestor already in the tree. Keep member refs or `find_child(name, true, false)`. `Camera3D.look_at()` also requires in-tree; use `look_at_from_position()` while assembling a SubViewport.

### Map and runtime integration
- P0-185 shader peel: move inline `*_SHADER_CODE` bodies to sibling `*.gdshader`, preload them in `map_view_material_shaders.gd`, and switch consumers to `shader_resource()`. Contract tests should read `WATER_SHADER.code`, not a removed string const. When `sed`-extracting from triple-quoted GDScript, skip the `const NAME := """` header and trailing `"""`; map edits trigger pre-commit `verify_map_audit.py`, so regenerate missing `docs/reports/images/map_audit/*.png` with `tools/capture_map_audit.gd -- --maps=id1,id2` before committing.
- P0-185 terrain peel: move dry-terrain caches, blended-ground splats, cobble arrays, and mud-wetness updates from `map_view_materials.gd` into `map_view_terrain_materials.gd`; re-export `TERRAIN_PATTERN`, `BLEND_TERRAIN_ORDER`, and repeat constants on the facade via `TERRAIN_MATERIALS.*`; keep `PATTERN_*` on the facade for `map_view_material_patterns.gd`. Gate with `test_map_view_material_resolution`, `test_map_terrain_chunks`, `test_street_and_masonry_realism`, and `test_natural_ground_variation`.
- P0-185 tree profile peel: move `_profile_for` / `_profile` from `map_view_tree_meshes.gd` into `map_view_tree_mesh_profiles.gd` with a public `profile_for()`; keep mesh emitters and budget constants on the facade. Gate with `test_map_view_tree_species` and `test_vegetation_realism`.
- P0-185 smithy prop peel: move smithy GLB loaders, furnace fire/particle helpers, and procedural fallbacks from `map_view_mesh_builder_prop_models.gd` into `map_view_smithy_prop_builder.gd` with public `add_*` methods and stable `*_PROP_ID` constants. Keep `build_prop` routing on the facade. Gate with `test_map_view_3d_mesh`, `test_environment_kit_catalog`, and `test_street_and_masonry_realism`.
- P0-185 runtime ambient peel: move bird/insect audio, bird flight, urban/penned fauna, music-zone binding, and crowd rendering from `map_view_runtime.gd` into `map_view_runtime_ambient.gd` with `configure()`, `install()`, and `sync()`; keep the public `MapViewRuntime` API as thin delegates. Gate with `test_map_view_3d_runtime`, `test_map_view_urban_fauna`, `test_map_view_penned_fauna`, and `test_map_view_crowd_renderer`.
- P0-185 time-flow peel: move the speed ladder, pause state, and weather time-scale sync from `map_view_runtime.gd` into `map_view_runtime_time_flow.gd` with `configure(host, on_changed)` in `_init()`; keep `time_flow_changed`, `TIME_SPEED_LADDER`, and property passthrough on the facade. Gate with `test_map_view_3d_runtime` and `test_debug_overlay`.
- P0-185 runtime session peel: move SessionState equipment binding, calendar-date sync, and phase hooks from `map_view_runtime.gd` into `map_view_runtime_session.gd` with `configure(host, actors, environment)`; keep `_equipment_state` as a read-only compatibility alias and `_current_calendar_date()` on the facade for tests. Gate with `test_session_state_replacement` and `test_map_view_3d_runtime`.
- P0-185 flat-map peel: move install-time 2D art hiding from `map_view_runtime.gd` into `map_view_runtime_flat_map.gd`; keep `_hide_flat_map_visuals()` as a static facade delegate for existing tests. New `class_name` scripts need tracked `.uid` sidecars before tests reference them directly.
- P0-185 runtime input peel: move MapClickInput install and `_unhandled_input` camera zoom/gesture/time-key routing from `map_view_runtime.gd` into `map_view_runtime_input.gd` with `configure(host, player)` during `install()` (player is null in `_init()`); keep public camera/zoom/movement methods on the facade. Gate with `test_map_click_input_controller`, `test_map_view_runtime_camera`, and `test_map_view_3d_runtime`.
- A new `view_landmark` kind needs `MapDefinition.VIEW_LANDMARK_KINDS`, the `_compile_landmark` field copy, and `LANDMARK_OVERRIDE_KEYS`. A new typed style key also needs `map_blueprint_compiler_build.gd` and expand-geometry validation.
- RRMap walls with `openings=` compile into `<id>/segment.NNN` buildings. `exclude` rects create blocked cells; keep reserved footprints clear of every anchor centre.
- `test_map_composition_audit` indexes thresholds by every blueprint-registry id. Add a card (`enforce: false` for developer-only interiors) with each new registry entry.
- RRMap stable IDs are lowercase-only. Production house GLBs hide procedural Walls/Roof/Chimney; skip invisible subtrees before collecting merge leaves or chimneys bake at the wrong height.
- When peeling RefCounted helpers off `MapViewRuntimeCamera`, call `_safety.configure(self)` before `_apply_camera_mode()` because mode apply runs `follow_player()` immediately.
- Penned fauna `configure` must receive the compiled `MapDefinition`. Building footprints are logic pixels; actor positions are world XZ. Convert with `MapViewBridge.logic_rect_to_world_xz`.
- Shared quadruped livestock GLBs are authored facing -X, while ambient `look_at` walks along -Z. Keep `MODEL_YAW = -PI * 0.5` on the imported model root.
- New Game places the player via DoorNavigator spawn `smithy_start`, not `definition.player_spawn`. Keep `transition smithy_start_spawn` on the same wake cell as `ap.sleep.wake`.
- Retiring a stable outdoor prop ID requires regenerating `lower_town_slice.parity.json` in the same change.
- After `SaveService` reload, compare remembered fields (`act_boundary`, quest state, flags, validated envelope), not raw `Dictionary` equality. JSON round-trip widens ints to floats.

### Packaging and generated files
- Godot 4.7 export-pack writes PCK format v4. Parse `dir_offset` after `file_base`. Required shipped files may appear as `.import` / `.remap` / `.gdc` or `.godot/imported/<basename>-<hash>.*`.
- Do not overwrite `build/act1/rr.dmg`. That path is the frozen Act 1 SHA bind. Use `build/inventory/` for after-packs.
- After `generated/.gdignore`, burgher rebuild-brief tests must `FileAccess.open(ProjectSettings.globalize_path(path))`.
- Act 1 packaged smoke can print `P3-012_PACKAGED_PLATFORM_PASS` and still emit Compatibility RID leak noise. Treat that as non-blocking in `tools/verify_act1_release.sh`.
- Blender-authored generators import `bpy`. Invoke them through Blender's bundled Python, not repository `python3`.
- Blender glTF export with packed textures still yields Godot-extracted `*_albedo.png` / `*_normal.png` / `*_roughness.png` sidecars. Register those derived paths in `assets/SOURCES.csv`.
- When `git push` ends with `broken pipe`, compare `git ls-remote` with local `HEAD`. If GitHub SSH port 22 is closed, retry once through `ssh.github.com:443`.
