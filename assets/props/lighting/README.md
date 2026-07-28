# Medieval household lighting kit

`medieval_lighting_kit.glb` is the game-ready artificial-light set for Reval in 1343. It is generated deterministically by `tools/generate_medieval_lighting_kit.py`; no `.blend` source is required.

## Authoring contract

All models continue to use the existing `candle` prop kind so interaction and day/night behavior stay shared. The map explicitly selects the fuel and holder through `style_variant`:

```text
prop poor_light candle 8 11 style_variant=poor_tallow
prop work_light candle 8 11 style_variant=artisan_tallow
prop merchant_light candle 8 11 style_variant=rich_beeswax
prop task_lamp candle 8 11 style_variant=grease_lamp
prop splint_light candle 8 11 style_variant=pine_splint
```

| Variant | Intended placement | Model cues | Historical confidence |
|---|---|---|---|
| `poor_tallow` | Poor urban or rural household | Short irregular tallow candle, crude iron socket and drip pan | Plausible composite. Tallow is medieval, but no Reval-specific 1343 holder/fuel pairing was found. |
| `artisan_tallow` | Craft household, workshop, ordinary burgher interior | Taller tallow candle on a stable forged-iron pricket stand | Plausible composite. This is the default and the authored Kalev smithy variant. |
| `rich_beeswax` | Affluent merchant house, altar, ceremonial room | Cleaner yellow beeswax candle on a turned copper-alloy pricket stand | Attested object form; status placement is a cost-based composite, not a Reval household inventory claim. |
| `grease_lamp` | Close task lighting in a workshop or service room | Open sooted redware bowl, rendered animal fat and exposed wick | Plausible composite. Medieval ceramic/fat lamps are attested outside Reval; local 1343 evidence remains absent. |
| `pine_splint` | Poorest/rural reconstruction or exceptional workshop dressing | Resinous pine splint in a forged clamp | Low-confidence reconstruction. The material is old, but the closest inspected museum clamp is dated only to the 16th-17th centuries. Do not use as the default Reval light. |

Unknown candle variants fail map compilation. Runtime fallback to `artisan_tallow` exists only as a defensive API guard.

## Art and runtime decisions

- Fuel, holder silhouette, height, metal, flame color, range, and energy change together. Social class is not represented by recoloring one universal candle.
- Every variant is an independent child root inside one GLB. Runtime removes the unused roots, so hidden geometry is not rendered.
- Every authored variant contains the holder, fuel, and charred wick plus a `FlameAnchor` marker, but no flame geometry. The same models can therefore be reused unlit without hiding or editing a mesh.
- Runtime attaches a small `GPUParticles3D` fire effect to `FlameAnchor`. Overlapping tapered billboards rise, shrink, change from pale yellow to orange, and fade independently; `CandleLight3D` adds non-synchronized light flicker.
- The generated 512 px albedos use broad painted wear below character-detail priority. There are no arbitrary Blender-only shader nodes.
- The set totals 2,424 triangles across holder and fuel meshes only. Individual variants range from 132 to 820 triangles and retain a zero-ground pivot.
- The existing hearth remains the main ambient source in ordinary interiors. These props represent expensive or task-specific supplementary light.

## Historically restrained exclusions

- **Modern molded pillar candles and saucer holders:** not used.
- **Paraffin:** post-medieval and rejected by the variant allowlist.
- **Roman-style closed oil lamps as a universal medieval default:** not used. The production lamp is an open fat-lamp composite.
- **Lantern:** not shipped in this set. A reported archaeological lantern from Lubeck is 15th century, while commercial reconstructions often claim a 14th-century Museum of London model without exposing enough primary catalogue data. Add a lantern only after a dated northern object is documented.
- **Rushlight:** not shipped. Easily available descriptions and surviving holders are predominantly English and/or early modern; they are not sufficient evidence for making a rush-pith light the default in 1343 Reval.
- **Torch:** reserved for exceptional outdoor, guard, or ceremonial use rather than normal domestic room lighting.

## Evidence and limits

No excavated Reval lighting assemblage securely dated to 1343 was found in the available project research or web search. The kit therefore separates dated object evidence from broader northern-European reconstruction:

1. The Metropolitan Museum of Art, [Pricket Candlestick, South Netherlandish, ca. 1300](https://www.metmuseum.org/art/collection/search/467703), copper alloy, 16.4 cm high. Strong dated reference for the rich pricket-holder family.
2. The Metropolitan Museum of Art, [Pricket Candlestick, Northern European or British, 13th century](https://www.metmuseum.org/art/collection/search/469867), copper with traces of gilding, 9.2 cm high. Strong northern reference for a compact pricket form.
3. Victoria and Albert Museum, [bronze candlestick, Magdeburg](http://collections.vam.ac.uk/item/O69137/), catalogue range 1200-1400 and object description c. 1150-1160. Confirms pricket technology and copper-alloy domestic display, but its elephant form was deliberately not copied.
4. Natan Heidbuchel, Maxime Poulain, and Wim De Clercq, ["Shedding Some Light on Indoor Lighting in 15th-Century Flemish Urban Houses: An Experimental Archaeological Approach"](https://doi.org/10.1080/00766097.2024.2419279), *Medieval Archaeology* 68.2 (2024), 382-405. Later urban comparandum for placement and light performance, not direct 1343 evidence.
5. Jacquelyn Frith, Ruth Appleby, Rebecca Stacey, and Carl Heron, ["Sweetness and Light: Chemical Evidence of Beeswax and Tallow Candles at Fountains Abbey, North Yorkshire"](https://doi.org/10.5284/1071958), Archaeology Data Service record. Material evidence that both beeswax and tallow reached medieval candle holders; monastic England is not a Reval status table.
6. T. Bitterli, "A Light is On in the Hut: Light and Lighting Equipment in Medieval Everyday Life," in I. Motsianos and K. S. Garnett (eds.), *Glass, Wax and Metal: Lighting Technologies in Late Antique, Byzantine and Medieval Times* (Archaeopress, 2019). Comparative basis for simple bowl-shaped fat lamps and the caution that such equipment is poorly represented archaeologically.
7. Kulturmuseum St. Gallen, [Kienspanhalter, 16th-17th century](https://online-collection.ch/objektId=27399), forged iron, wood and pine splint, 40 cm high. Documents how resinous splints and clamps work, while its late date is why `pine_splint` is explicitly low-confidence.

## Regeneration and verification

```bash
blender --background --factory-startup --python tools/generate_medieval_lighting_kit.py -- --preview
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_medieval_lighting_assets
```

Compact reports and the preview are written to `generated/blender/medieval_lighting_kit_v1/` and remain local generated evidence per the repository storage policy.
