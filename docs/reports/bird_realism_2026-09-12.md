# Naturalistic bird revision — P0-207

The maintainer requested substantially more realistic bird models, with Witcher 3
as a fidelity reference. This replaces the live robin, hooded crow, gull, hen and
mallard assets at their existing paths. All geometry, procedural texture pixels
and bird motion are original project work; no game models or textures were copied.

## Visible changes

- Continuous torso, neck and skull surfaces with distinct species proportions and
  pigmentation, including the robin breast and mallard head/collar/chest.
- Thin asymmetric, cambered primary/secondary feathers, layered dorsal and ventral
  coverts, individual tail feathers, and compact resting wings that open in flight.
- Separate curved upper/lower bills, nostrils, inset eyes, scaly tarsi, bent toes,
  claws and webbed gull/mallard feet. The mallard stands lower than the land birds.
- Embedded directional albedo, normal and roughness maps, matte plumage, harder
  keratin and glossy eyes. Geometry remains opaque, avoiding feather transparency
  sorting in Compatibility.

The [matched before](images/bird_realism/before.png) and
[after](images/bird_realism/after.png) plates use actual imported Godot models and
the same camera/light setup. Additional [flight planforms](images/bird_realism/flight.png)
and [motion phases](images/bird_realism/motion.png) inspect the imported wings from above.
Reproduce these with `-- --flight-sheet --output=res://docs/reports/images/bird_realism/flight.png`
or `-- --motion-sheet --output=res://docs/reports/images/bird_realism/motion.png`.
This is a naturalistic improvement to generated game
assets, not a claim to match an AAA studio's finished wildlife. Dedicated distance
LODs and species-specific feather spreading remain further production work.
The broader legacy bird catalogue still uses its existing assets.

## Sources and implementation

Anatomical reference checks: [RSPB hooded crow](https://www.rspb.org.uk/birds-and-wildlife/hooded-crow),
[RSPB herring gull](https://www.rspb.org.uk/birds-and-wildlife/herring-gull).
References inform anatomy/markings only. The generator is
`tools/assets/storybook_birds.py`, called by `build_storybook_models.py`.

The GLBs retain nine named bones and eight clips: Idle, Walk, Hop, Peck, TakeOff,
Fly, Glide and Land. Takeoff/landing include wing compaction scales, with matching
endpoints across Idle → TakeOff → Fly → Glide → Land → Idle. No runtime actor
references, species IDs, ecology, maps, collision, input or save data changed.

Blender 5.2 dropped named vertex colors on later surfaces of a joined mesh. The
exporter now separates material sections while retaining one skin. Godot 4.7.1
also left vertex pigmentation disabled; the import hook installs a small PBR
shader that converts linear glTF pigmentation only for Compatibility's sRGB
output. The [Godot material documentation](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html#class-basematerial3d-property-vertex-color-is-srgb)
confirms its standard vertex color space switch only affects Forward+/Mobile.
The runtime shader lives under `assets/` because release exports exclude `tools/`.
Embedded-image import mode 3 avoids duplicated extracted PNG dependencies.

## Reproduction

```sh
blender -b -t 6 --python-exit-code 1 --python tools/assets/build_storybook_models.py -- --birds-only
godot --headless --path . --editor --import
python3 tools/verify_storybook_models.py
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_storybook_models,test_storybook_live_integration,test_map_view_bird_meshes,test_map_view_bird_flight
godot --path . --script tools/capture_bird_model_review.gd
python3 tools/validate_asset_sources.py
git diff --check
```

Editable sources remain in ignored `build/storybook/*.blend`. The verifier checks
every material's pigmentation, embedded PBR maps and noncollapsed UVs in addition
to the existing budget, weights, named bones, animation and transition checks.
The Godot regression test verifies the actual imported shader and texture bindings.

## Final verification

- Blender 5.2.0 rebuild and Godot 4.7.1 import completed. All five birds pass the
  portable verifier: 53,272–57,706 triangles, 2.70–2.90 MB per GLB, nine bones and
  eight clips each. The full 22-model verifier also passes.
- Focused Godot suite: **34 tests across four files, zero failures and zero harness
  errors**, including imported PBR bindings, the existing live bird pool,
  standing/flying rigs, phase transitions and showcase controls. Existing shared
  scene cleanup still emits retained-resource warnings at shutdown.
- Provenance schema/coverage and `git diff --check` pass. Only the five bird rows
  and the new runtime shader row were authored for this pass; concurrent asset
  work has its own records.
- Broader `test_map_view_bird_species` retains 15 under-modeled-silhouette failures
  on the older procedural bird catalogue. The active-doc check retains nine
  existing root-document issues and a stale generated report. Neither was repaired
  or claimed green. No full-project test result is claimed for this asset pass.
- Independent second review approved correctness and integration. It checked
  weights, UVs, PBR bindings, budget, bill winding, packaging and every sampled
  wing transform: maximum left/right mirrored-transform error was **zero**.

Remaining visual limits are simplified anatomy, regular feather rows and approximate
wing folding. These are more detailed game assets, not Witcher 3 production fidelity.

The workspace had simultaneous character/mammal generator edits. An early invocation
began regenerating current human outputs before the bird selector was made compatible
with the concurrent mammal selector; it was stopped. Subsequent builds used the
isolated bird selection. A check against Mart's saved pre-run Blender source found
identical export JSON, vertex positions/normals, skin and animation data, with only
triangulation and tiny UV roundoff differences. No human design edits were authored
for this task, and no files were staged or committed.
