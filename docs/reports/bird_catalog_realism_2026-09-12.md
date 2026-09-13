# Ambient bird catalogue realism — P0-212

Maintainer request: “improve other bird models too.” Implemented September 12–13,
2026, following the five skinned bird revisions in P0-207.

## Player-visible change

All 30 existing ambient species now use a deterministic, cached anatomy builder
for standing, perched and gliding geometry. This replaces the old low-poly
fallback and bypasses older static GLBs in the live catalogue. Those legacy
files remain available through `MapViewBirdAssets` for reference; they have not
been overwritten. The existing five skinned assets and their animation clips
remain unchanged, including their live-flight selection.

The new geometry includes continuous torso/neck/skull surfaces, layered curved
primary/secondary/covert feathers, twelve tail feathers, separate upper/lower
bills or broad waterfowl bills, nostrils, inset eyes, articulated toes and claws,
and webbing for waterfowl, gulls and terns. Waders, swans and cormorants have
curved necks; flying herons retract their neck while swans extend it. Raptors
have hooked bills; owls have facial discs; swallows/terns have forked tails;
woodpeckers have two forward and two rear toes. Species-specific pigmentation
adds masks, cheek patches, wing bars, pale eagle tails and breast markings.

A single lit shader separates feather, keratin and cornea response through
vertex material tags. Feather vanes have UVs, smooth normals, tangents and fine
barb detail. Markings and geometry are deterministic. No map content, ecology,
spawn IDs, collision, input, persistence or gameplay changed.

## Live flight

The renderer builds only a cached neutral model when installing an ambient rig.
Each complete feather is assigned to its anatomical wing section, with explicit
shoulder/wrist anchors. The previous centroid splitter would divide individual
vanes across joints and tear them during flight. UVs, normals and material tags
are preserved when assembling the five runtime mesh parts. The live renderer
retains the new shader instead of applying the old procedural override.

The eight-frame inspection API remains available. Existing skinned species use
their established models. Flight and grounded-bird selection APIs retain their
stable species names.

## Visual evidence

Captured with Godot 4.7.1, GL Compatibility, on Apple M5 Pro. Each cell fits its
model bounds independently; this is a silhouette/material comparison, not a
scale comparison. Both sides use the same lighting and camera direction.

| Catalogue group | Before | After |
|---|---|---|
| Gulls, tern, swan, mallard, goose | [Before](images/bird_catalog_realism/before_0.png) | [After](images/bird_catalog_realism/after_0.png) |
| Cormorant, heron, lapwing, snipe, eagle, osprey | [Before](images/bird_catalog_realism/before_1.png) | [After](images/bird_catalog_realism/after_1.png) |
| Buzzard, kestrel, owl, sparrow, crow, rook | [Before](images/bird_catalog_realism/before_2.png) | [After](images/bird_catalog_realism/after_2.png) |
| Jackdaw, magpie, swallow, skylark, yellowhammer, chaffinch | [Before](images/bird_catalog_realism/before_3.png) | [After](images/bird_catalog_realism/after_3.png) |
| Tit, robin, blackbird, thrush, nightingale, woodpecker | [Before](images/bird_catalog_realism/before_4.png) | [After](images/bird_catalog_realism/after_4.png) |

[Neutral flight](images/bird_catalog_realism/flight_1.png),
[actual installed wader/raptor rigs during a stroke](images/bird_catalog_realism/stroke_1.png),
and [actual installed corvid/songbird rigs during a stroke](images/bird_catalog_realism/stroke_3.png).
The black/disconnected pre-change water birds are the actual old static-loader
output, which discarded scene transforms when taking the first mesh. They were
not artificially degraded for the comparison.

Reproduce a six-species sheet with `--page=0` through `--page=4`:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/capture_bird_catalog.gd -- --page=1 --output=res://docs/reports/images/bird_catalog_realism/after_1.png
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/capture_bird_catalog.gd -- --page=1 --stroke=4 --output=res://docs/reports/images/bird_catalog_realism/stroke_1.png
```

## Verification and review

- Focused bird catalogue, mesh, flight, audio, storybook and live integration:
  **51 headless tests across seven files, zero failures and zero harness errors**.
  Fifty of those tests also passed in GL Compatibility; the added exhaustive
  240-frame topology check runs headlessly. Covers all 90 species/pose pairs, finite unit
  normals, UVs, material tags, deterministic rebuilds, valid IDs, geometry limits,
  preserved rig parts, shader installation and species-specific flight posture.
- Ambient geometry stays below the **8,000-triangle** limit. The final maximum
  is **7,284 triangles**, reported by `test_bird_catalog_realism`; no 50k-triangle hero bird meshes
  are duplicated across the full catalogue.
- Independent reviewer confirmed valid flight normals across all 30 species,
  preserved shading and intact vanes in the actual non-neutral runtime capture.
  Shared source points crossing joint ownership fell from 131–211 per bird to
  **zero** after the component ownership fix. Missing tern webbing was also fixed.
- `git diff --check`: passes. The repository-wide provenance validator currently
  reports three unrelated, concurrently added Kalev reference images lacking
  manifest rows. The new bird shader has its own source/rights/approval record.
- The active-doc check retains unrelated README issues and a stale report. No
  blanket green result is claimed. Shared autoload teardown still emits the
  previously recorded retained ObjectDB/resource warnings after successful tests.
  The rendered test run also reported a host audio-device start error; rendering
  and all test assertions completed successfully.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_bird_catalog_realism,test_map_view_bird_species,test_map_view_bird_meshes,test_map_view_bird_flight,test_storybook_live_integration,test_storybook_models,test_map_view_bird_ambient_audio
python3 tools/validate_asset_sources.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

## Art references and limits

Original procedural geometry and shader art; no copied game assets. RSPB
[white-tailed eagle](https://www.rspb.org.uk/birds-and-wildlife/white-tailed-eagle),
[osprey](https://www.rspb.org.uk/birds-and-wildlife/osprey),
[grey heron](https://www.rspb.org.uk/birds-and-wildlife/grey-heron), and
[lapwing](https://www.rspb.org.uk/birds-and-wildlife/lapwing) guide recognition
features. Existing catalogue data remains the source of species scale and ecology.

This is a broad ambient-model realism improvement, not Witcher 3/AAA equivalence.
Simplified contours, repeated procedural feather/marking patterns and rigid
wing sections remain visible in close-ups. The models do not gain individual
high-resolution hand-painted textures, full skeletal skinning or new ground
locomotion. The standing/perched pose vocabulary and existing runtime behavior
remain within their previous scope.
