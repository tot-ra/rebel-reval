# Vegetation realism — P0-208

Maintainer request: “improve vegetation system. think of witcher 3 type of realism”.
Recorded: 2026-09-12. Implementation and focused review complete; repository-wide acceptance gates remain blocked as listed below.

## Player-visible changes

- Grass uses 14 narrow, independently curved blades per cached tuft, replacing seven wide angular blades. Roots stay fixed; height, lean and color vary deterministically.
- Broadleaf trees use folded, asymmetric leaf surfaces. Oak/maple/hawthorn have lobed outlines; birch has a tapered outline; alder/aspen/hazel/linden are rounder; willow/ash/rowan are narrow. Conifers carry paired needle sprays rather than isolated diamond leaves. Existing tree skeletons, species IDs, fruit and authored positions remain intact.
- Grass and leaves receive restrained light-driven transmission and filtered midrib/vein detail. Correct clockwise normals and the renderer's existing two-sided handling replace the previous duplicate normal inversion. No emission is used.
- Broad wind gusts share world position, direction and time. Fine flutter varies spatially. World displacement converts back through the instance transform, so rotated/scaled MultiMesh plants lean with the same wind. Zero wind stops motion. Grass still parts around the player.
- Nearby ground cover uses smooth seeded patches, varied heights and a bounded number of tufts. It respects building footprints and the existing close-camera detail window. Overhead detail remains geometry-free. Untagged bushes retain their existing height-based wind through the shared canopy material.

This is a procedural vegetation improvement toward the requested reference, not a claim of Witcher 3 asset fidelity. Mature crown density, more detailed woody branches, richer understory assets and measured distance LODs remain future work. No copied game assets, map content, collision, navigation, movement modifiers, inventory, input bindings or persistence formats changed.

## Evidence

Rendered with Godot **4.7.1**, **OpenGL Compatibility**, 1440 × 900, 4× MSAA. The mesh review uses the same species, plant instances, camera and lighting before/after. Wind samples are captured at fixed simulation FPS; animation phase is not claimed to match between revisions.

| View | Before | After |
| --- | --- | --- |
| Grass at eye level | [Before](images/vegetation_realism/before/grass.png) | [After](images/vegetation_realism/after/grass.png) |
| Five tree silhouettes | [Before](images/vegetation_realism/before/stand.png) | [After](images/vegetation_realism/after/stand.png) |

[District ground sample](images/vegetation_realism/after/district_cover.png) renders the real Lower Town terrain and nearby-cover builder with authored seed, heights and styles. This isolates vegetation; buildings are intentionally omitted in that sample. [Live district view](images/vegetation_realism/after/district_live.png) includes the production MapView3D scene. The earlier `before/district_cover.png` was a flat-stage diagnostic and is **not** a matched terrain comparison.

Rendered behavioral evidence:

- `after/calm_a.png` and `calm_b.png`: zero changed pixels.
- `after/wind_a.png` and `wind_b.png`: moving grass/leaves, 593,590 changed pixels.
- `after/bush_wind_a.png` and `bush_wind_b.png`: moving legacy shrub with no leaf UVs, 10,200 changed pixels.
- `after/unlit.png`: all RGB channels zero with direct and ambient lighting off; transmission does not glow in darkness.

[Capture manifest](images/vegetation_realism/capture_manifest.json) records image dimensions, hashes and pixel comparison results.

Reproduce current captures:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 1440x900 --fixed-fps 30 --script tools/capture_vegetation_realism.gd -- after
```

The `before` argument is only an output label: baseline screenshots were captured before modifying the runtime sources. Passing that label on the new code does not reconstruct the old visuals.

## Verification

- Focused headless suite: **64 tests, 8 files, zero failures/errors**.
- Same 64 tests under the real OpenGL renderer: **zero failures/errors**. This matters because the dummy renderer discards MultiMesh transform buffers. The real-renderer run validates exact instance positions, scale, color and building clearance for whole versus split chunks.
- Geometry checks cover deterministic rebuilds of all 20 species, finite unit normals, clockwise face alignment, non-degenerate triangles, explicit leaf UV tags and triangle caps.
- Existing grass interaction, tree/bush catalog, terrain-detail and outdoor-map tests pass.
- Independent second reviewer confirmed correctness, simplicity and scope after fixes to backface shading and the legacy bush UV fallback.
- Map activation and map conversion-plan validators pass (127 scenes).
- `git diff --check` passes for the vegetation change.

Commands:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_vegetation_realism,test_grass_interaction,test_map_view_tree_species,test_map_view_bush_species,test_map_view_terrain_details,test_terrain_vegetation,test_map_view_3d_mesh,test_outdoor_map_packages
# Repeat without --headless for actual MultiMesh buffer verification.
python3 tools/verify_map_activation.py
python3 tools/verify_map_conversion_plan.py
```

Repository-wide checks on this dirty checkout are not green:

- Full Godot suite: stopped after failures with 169 test files reached (168 assertion failures and 7 test/file errors recorded). It was in `test_map_quality_audit` route validation when stopped; this is **not a complete full-suite result**. Observed failures include unrelated Act 2 content loading and hammer equipment profiles, plus missing script/resource dependencies. The 64 relevant tests completed independently in both renderers.
- Map audit: missing captures for `kuldjala_interior`, `nunnatorn_interior`, `rentenitorn_interior`, and `toompea_small_castle`.
- Active docs: stale generated report and nine broken relative links in the already-modified root README. The vegetation changes introduce no active-link failure. Existing unrelated edits were preserved.
- Both baseline and changed Godot runs print resource/instance leak diagnostics at process teardown; the focused harness itself reports zero failures/errors. This pass does not claim to resolve global resource cleanup.

## Cost and limits

Grass increases from **21 to 98 triangles/tuft**. Broadleaf canopies range from **4,896 to 11,648 triangles**; spruce has **20,160**, pine **19,040**, juniper **17,640**. The test cap is **24,000 triangles/canopy** and **112/grass tuft**. Close detail is capped at at most 12 total instances/cell and continues to use four possible existing foliage batches. All meshes stay cached and reused by MultiMesh; there are no per-blade or per-leaf nodes or new textures.

These caps do not prove frame-rate parity. Increased vertex cost and denser nearby cover need representative hardware profiling before any 60-FPS or performance-parity claim. Keyboard/gamepad behavior and save/load need no new interaction path because this change only consumes existing view/grass-interaction inputs and changes no persisted state.

Implementation references: Godot's [spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html) documents `BACKLIGHT`; the [4.7 GLES3 scene shader](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/shaders/scene.glsl) supplies automatic two-sided normal handling.
