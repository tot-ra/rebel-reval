# P0-036 visual targets - Smithy Courtyard

Recorded: 2026-07-16  
Scene: `scenes/map_prototype/smithy_courtyard.tscn`  
Godot: `4.7.1.stable.official.a13da4feb`, GL Compatibility  
Capture viewport: 1600 x 900

## Scope and invariant contract

P0-036 is a visual comparison, not an active-district conversion. Pixel, digital woodcut, and clean-painted are rendering-only profiles over one unchanged scene composition and one `SmithyCourtyardDefinition`.

Invariant across targets:

- world: 1600 x 896, 50 x 28 cells, 32 px cells;
- camera: `(800, 448)`, zoom `1.0`;
- the same terrain grid fingerprint and all seven terrain IDs;
- the same 8 medieval building footprints and collision rectangles;
- the same 5 prop kinds and ground anchors;
- the same player spawn, 28 x 20 collision footprint, 64 px visible height, and `(0, 18)` pivot;
- the same shared `Actors` Y-sort parent.

The `.tscn` change adds only a capture label. Camera, Actors, and Player transform values did not change. `scripts/map/smithy_courtyard_definition.gd` was not modified.

## Visual targets

| Target | Day | Night | Intended comparison signal |
|---|---|---|---|
| Pixel | [capture](images/p0_036_pixel_day.png) | [capture](images/p0_036_pixel_night.png) | 4 px terrain clusters, 2 px outlines, compact indexed-feeling palette |
| Digital woodcut | [capture](images/p0_036_digital_woodcut_day.png) | [capture](images/p0_036_digital_woodcut_night.png) | directional hatch, 3 px ink outlines, parchment/earth palette |
| Clean painted | [capture](images/p0_036_clean_painted_day.png) | [capture](images/p0_036_clean_painted_night.png) | broad material planes, sparse soft marks, 1 px separation outline |

Each capture includes grass, sand, hay, dirt, cobblestone, water, and stone; gabled plaster/timber buildings and limestone walls; anvil, hay stack, cart, well, and barrels; Kalev's comparison figure; and overlap cases under shared Y-sort.

## Repeatable capture

A graphics renderer is required because the headless dummy renderer has no viewport texture.

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
mkdir -p docs/reports/images
for target in pixel digital_woodcut clean_painted; do
  for phase in day night; do
    "$GODOT" --path . --script scenes/map_prototype/capture_visual_target.gd -- \
      "$target" "$phase" "docs/reports/images/p0_036_${target}_${phase}.png"
  done
done
```

## Objective verification

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . --script scenes/map_prototype/verify_visual_targets.gd
"$GODOT" --headless --path . --script tools/run_godot_tests.gd
```

Verified locally on 2026-07-16. Both commands exited `0`.

```text
P0-036 visual target verification: PASS
 - immutable geometry/camera/collisions/scale: ok
 - seven terrain types: ok
 - medieval buildings and five prop kinds: ok
 - character pivot/height and Y-sort: ok
 - three distinct 1600x900 day captures: ok
 - night captures preserve visibility and reduce luminance: ok

Godot headless tests: 6 file(s), 50 test(s), 0 failure(s), 0 error(s).
```

The verifier loads all targets independently and compares a shared signature containing world size, camera, zoom, terrain fingerprint, building footprints, prop positions, player spawn/collision/pivot, and Y-sort. It also checks PNG dimensions, distinct day-image hashes, absence of error magenta, and a minimum 20% day-to-night luminance reduction.

Measured sampled luminance from the verifier:

| Target | Day | Night | Night/day |
|---|---:|---:|---:|
| Pixel | 0.3891 | 0.1891 | 0.486 |
| Digital woodcut | 0.4125 | 0.2012 | 0.488 |
| Clean painted | 0.4459 | 0.2078 | 0.466 |

## Capture checksums

```text
8e098c865d04e3375d45a75b36170eeeff69c67077ef7765bc9ac323c3e4bd40  p0_036_clean_painted_day.png
09642f009728d1d249df25d14ccba7c6dbc6f1063c17a9eedf327e5c21caa6d0  p0_036_clean_painted_night.png
15624fc129c928b7e44db19d23644bc6df42eac1f52dea78f47a765e93ed5d5a  p0_036_digital_woodcut_day.png
0dfe9cfd59c95149eb0cee9ce278e9085309e7dd31e0d3790dcbf26a63dd0741  p0_036_digital_woodcut_night.png
a026a42cc034fdb9c4b979f19795dff8471c9171238b5aecb1a14b3ada635803  p0_036_pixel_day.png
eaa3b1e72cceae39e6b8f660f84225e0a25ba50df3d4080cb1d8d2d6e768e4b0  p0_036_pixel_night.png
```

## Result

P0-036 is complete: the three targets were captured and reviewed at identical framing and gameplay scale with objective invariant checks. The clean-painted profile is the recommendation for P0-040, with restrained woodcut accents. This is not P0-040 approval. P0-038, P0-039, and human approval remain required, and active districts remain frozen.
