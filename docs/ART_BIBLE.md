# Art Bible

Status: **Approved**
Recorded: 2026-07-16  
Evidence: [P0-036 visual target report](reports/visual_targets_p0_036.md), [P0-036 UX review](reports/visual_targets_p0_036_ux_review.md), [ADR 0004](adr/0004-clean-painted-visual-style-candidate.md)

This document freezes the candidate rules exercised by the P0-036 Smithy Courtyard gate. It does not authorize conversion of active districts. Final approval remains blocked by P0-038, P0-039, and a human P0-040 decision.

## Candidate direction

- Engine: Godot 4.7, GL Compatibility.
- Perspective: orthogonal gameplay plane with three-quarter architectural art.
- Visual style: **clean-painted candidate**, with digital-woodcut line economy used only as a controlled accent, not full-surface hatching.
- Comparison source: the single composition `scenes/map_prototype/smithy_courtyard.tscn`.
- Negative constraints: no diamond-isometric physics, eight-direction sprite requirement, frame-specific character redraw pipeline, photorealism, unrestricted black outlines, or conversion of active districts before P0-040 approval.

## Resolution, camera, and scale

| Rule | Candidate value |
|---|---:|
| Internal viewport | 1600 x 900 |
| Smithy comparison world | 1600 x 896 |
| Camera | fixed orthogonal `Camera2D`, center `(800, 448)` |
| Gameplay zoom | `1.0` |
| Terrain authoring cell | 32 world px |
| Character visible height | 64 px |
| Character collision footprint | 28 x 20 px |
| Character root/pivot | ground contact at `(0, 18)` relative to root |
| Building pivot | center of south footprint edge |
| Prop pivot | authored ground anchor |

Art can overhang north/upward from an anchor. Collision, navigation, interaction distance, and Y-sort must use the ground-plane anchor and may not be inferred from transparent bounds or roof silhouettes.

## Candidate clean-painted palette

All values are sRGB day masters. Variations must remain recognizably within the same material family.

### Terrain

| Terrain | Hex | Value role |
|---|---|---|
| Grass | `#5D7E4E` | low-frequency ground |
| Sand | `#C7AB70` | light warm ground |
| Hay | `#CDA444` | warm material accent |
| Dirt | `#7C5841` | courtyard ground |
| Cobblestone | `#7E7D79` | neutral route |
| Water | `#3A748F` | cool landmark |
| Stone | `#93938B` | light neutral work surface |

### Architecture, props, and character

| Role | Hex |
|---|---|
| Ink/deep separation | `#2B2624` |
| Lime plaster | `#CDB892` |
| Structural timber | `#53372A` |
| Roof red-brown | `#6F3B31` |
| Cut stone | `#919189` |
| Iron | `#464F52` |
| Wood | `#774D2D` |
| Window cool light | `#689EB1` |
| Water highlight | `#65B1C4` |
| Kalev cloth accent | `#B23D31` |
| Skin | `#D8A97B` |
| Smith apron | `#536365` |

The red character cloth is the primary mobile accent. Hay and lit windows are secondary environmental accents. Do not distribute these accent values evenly across terrain.

## Outlines and marks

- Clean-painted target: 1 px deep-separation outline at 1.0 zoom.
- Outlines describe silhouette intersections and prop identity, not every internal material edge.
- Internal form uses color/value planes and restrained translucent wash.
- Digital-woodcut hatching may be used on selected roof, cloth, and narrative-print surfaces only. It must not cover all terrain cells.
- Pixel target remains comparison evidence, not the candidate production pipeline. Do not create new frame-animation assets from it.

## Shadows

- Day cast-shadow offset: `(7, 6)` px at 1.0 zoom.
- Day opacity: 22% using the deep-separation color.
- Night opacity multiplier: 72% of day shadow opacity because ambient darkness already supplies separation.
- Character and prop shadows stay compact and attached to the ground pivot.
- Shadows communicate contact and overlap. They never replace collision footprints or create fake interactive depth.

## Value hierarchy

From highest gameplay priority to lowest:

1. Player/NPC silhouette and interaction or combat feedback.
2. Interactable props such as anvil, well, cart, barrels, and hay stack.
3. Doors, passages, street-to-courtyard route, and collision boundaries.
4. Building identity: lime plaster, dark timber, red-brown roof, stone enclosure.
5. Terrain material texture.
6. Decorative marks and printmaking accents.

At gameplay scale, a grayscale/squint pass must preserve tiers 1-3. Texture marks must not create stronger edge density than the player or interactable silhouette.

## Day and night rules

- Author one day master palette. Night is a deterministic grade, not a separately recolored asset set.
- Non-emissive night colors use approximately `43% red / 50% green / 66% blue`, then blend 20% toward moonlit `#19233A`.
- Window and water highlights may blend 58% toward warm light `#EEB15C` to preserve landmarks.
- Night captures must average at least 20% darker than matching day captures while preserving all seven terrain identities.
- Do not use a full-screen opaque blue overlay that collapses character, route, and prop separation.
- Gameplay-critical prompts and silhouettes must remain above background value noise in both phases.

## Medieval Reval shape language

- Lower Town buildings use compact gabled roofs, pale lime plaster, visible timber framing, small cool windows, and dark timber doors.
- Stone enclosure walls use neutral local limestone with a lighter coping plane.
- Forge props prioritize immediate silhouette recognition: broad anvil face, cart wheels/shaft, well rim/water opening, barrel bands, and stacked rectangular hay bales.
- Architecture may exaggerate facade visibility for the three-quarter view, but footprints and street widths remain orthogonal.

## Approval gate

Before changing this status to `Approved`:

1. P0-037 proves the shared cutout rig at the frozen 64 px character scale.
2. P0-038 records performance and production measurements for the compared approach.
3. P0-039 runs a blind gameplay-scale readability test with at least five participants.
4. A human approver records accept/reject and any rule changes in ADR 0004.
5. Captures and automated geometry/collision/Y-sort verification remain green.

Until all five steps pass, active district scenes and production runtime assets remain frozen.
