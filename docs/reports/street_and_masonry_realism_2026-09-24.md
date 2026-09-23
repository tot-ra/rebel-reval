# Street surface and masonry realism (2026-09-24)

Maintainer request: make ground, paving, mud, puddles, loose stones and the city
wall / Viru Gate masonry read as a realistic, historically plausible 1343 Reval
instead of painted prototype surfaces.

Scope is procedural materials and gate geometry in the 3D view layer. No map
content, stable IDs, collision, navigation, save schema or gameplay values were
touched.

## Evidence

Matched perspective plates over the production `lower_town_slice` map, day
lighting, GL Compatibility renderer, 1280x720:

| Plate | Before | After |
|-------|--------|-------|
| Viru Street approach | `images/street_realism/viru_gate_approach_before.png` | `images/street_realism/viru_gate_approach_after.png` |
| Street surface | `images/street_realism/road_surface_before.png` | `images/street_realism/road_surface_after.png` |
| North city wall | `images/street_realism/city_wall_before.png` | `images/street_realism/city_wall_after.png` |
| Gate passage | `images/street_realism/gate_passage_before.png` | `images/street_realism/gate_passage_after.png` |

Regenerate with:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_street_realism.gd -- --label after
```

## What changed and why

### Ground

- **Packed-earth plate (`PATTERN_EARTH`).** Dirt streets used the generic
  speckle plate, a near-flat 0.84-1.00 grey multiplier. The new plate carries
  compacted silt, embedded gravel and limestone chips with contact shadow,
  drying cracks and trodden straw, and it varies in hue (dry dust versus damp
  hollow), not only in brightness.
- **Palette.** `TERRAIN_DIRT` moved from a saturated terracotta `#9A5A3F` to a
  grey-ochre `#6A6154`, with mud and farm soil desaturated to match. Reval
  streets are packed earth over limestone rubble and building waste; the old
  tint read as tropical red clay at gameplay range.
- **World-space relief.** The blended-ground shader now derives a height field
  for the trodden-ground layers (farm soil through ash), darkens the damp
  hollows, and builds a tangent normal from the same field. Earth previously had
  no normal at all and was lit as a perfectly flat plane.
- **Full-RGB pattern tinting.** Non-plate terrain layers previously used only the
  red channel of their plate, discarding any hue variation. Grayscale plates are
  unaffected (all channels equal); coloured plates now survive.
- **Paving edges.** Paving and earth meet through a world-space noise threshold
  instead of a straight interpolation, giving a worn interlocking edge.
- **Stone layer.** The authored interior flagstone plate is now tinted by the
  stone palette entry, and that entry moved from blue granite to warm limestone
  grey. Untinted, it rendered far brighter than the paving and earth it borders.

### Puddles

The puddle decal sampled `hint_screen_texture` and multiplied the result into
emission. Under the shipped GL Compatibility renderer this produced flat pale
sheets rather than the ground beneath. Puddles are now a darkening water film
with a fresnel sky sheen, which is both correct under alpha blending and cheaper
(no back-buffer copy per puddle). Outline noise was also smoothed so pools stop
reading as stars.

### Loose stones

Instance tints ran 0.80-1.15 over the rock albedo, so every street stone read as
a bright white egg. They are now weathered grey-brown 0.42-0.72 with warm/cool
variation, flatter, embedded slightly into the ground, and carry a normal map.

### Masonry: walls, towers, gates

- **Limestone rubble plate.** Reval's walls are coursed rubble: roughly levelled
  bands of irregular hand-split limestone in wide lime mortar. The previous plate
  was even machine ashlar with 16 identical courses. The new plate jitters course
  heights and block widths (both wrapping, so the plate still tiles), varies face
  tone, adds pitting, chipped arrises, and heavier bed joints than perpends so
  tall walls keep their horizontal reading.
- **Brick plate.** Hand-moulded, wood-fired brick: per-brick tone, occasional
  over-fired dark headers, wandering perpends and uneven mortar.
- **Masonry scale.** Repeats are now derived from real course heights. One world
  unit is about 0.87 m, a split limestone course about 0.3 m, a brick course about
  0.1 m; the previous repeats packed roughly six times that many courses into a
  wall, which is why fortifications read as printed grids.
- **Resolution and relief.** Masonry plates are generated at 256 px, and brick,
  limestone, plaster, plank and log materials now carry a normal map derived from
  the same plate. Flat, normal-less walls were the main reason fortifications
  looked like painted cardboard.
- **Arched gate head.** The gate passage was a flat lintel on two piers. It now
  springs into a segmental arch built from masonry bands whose inner edge follows
  the arc. Each band starts at the widest point of the span it covers, so the
  authored clear opening is never narrowed and collision is unchanged.

## Known remaining defect

**Paving fringe wedges.** Where a paving stroke ends, the terrain shows a row of
hard triangular wedges of pure paving reaching into the earth (visible in both
the before and after road-surface plates, lower right).

Cause, confirmed by debug renders during this pass: terrain layer indices are
`flat` per triangle while the blend weight interpolates, so a triangle whose
provoking vertex sits in a paving cell is drawn entirely as paving even where it
covers earth. Reducing the material contrast and adding the noise-warped edge
softens it, but the wedges follow the triangulation and cannot be removed from
the fragment shader alone: the fix belongs in the ground mesh builder, which
would need per-corner layer weights (three indices plus barycentric weights)
rather than one flat pair.

Verified *not* the cause, so a future fix should not re-investigate these:
puddle decals, wear decals, scatter meshes, terrain height relief, per-cell tone
jitter.
