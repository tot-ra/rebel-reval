# ADR 0022: Realistic human characters on a MakeHuman CC0 base

**Recorded:** 2026-09-26
**Supersedes:** [ADR 0018](0018-saturated-hdr-fantasy-anime-visual-direction.md) (fantasy/anime finish), [ADR 0020](0020-kalev-character-realism.md) (Kalev-only realism exception)
**Amends:** [ADR 0016](0016-tiered-character-fidelity.md) (tiers and budgets unchanged; the Tier 0/1 human source changes)

## Status

Accepted by maintainer direction, 2026-09-26: "rework human character 3d models. needs to be
realistic, historically accurate. think witcher 3 or kingdom come deliverance 2 ... MakeHuman /
MPFB is fine. yes remove fantasy/anime look ADR. keep realistic KCD2 baseline. need good realism
for all models. for key characters we can spend more time/quality polishing it. for main
character we want modularity to be able to wear different clothes, armour, weapons etc."

## Context

Three human pipelines co-existed and none reached the requested bar:

- **Procedural `PartBuilder` bodies** (`tools/generate_hero_body.py`, July "own mesh only" rule):
  primitive tubes and boxes; read as toy figures at dialogue distance whatever the tuning.
- **Kalev photo reconstruction** (`tools/assets/kalev_rebuild/`, P0-214/P0-220): a Hunyuan3D
  image-to-mesh scan with a projected photo atlas. The face read well from the front, but hair was
  painted onto the skull, sides and neck were smeared, clothing was crude offset shells, and every
  new character would be a one-off. The Tencent Hunyuan community licence also excludes the EU.
- **Storybook bodies** for the named cast under ADR 0018's saturated fantasy/anime finish.

Kingdom Come: Deliverance 2 and The Witcher 3 get their look from anatomically correct base
meshes with deformation-ready topology, groomed hair, skin detail maps and properly constructed,
period-correct clothing, not from more geometry.

## Decision

1. **Visual baseline is realistic and historically accurate** (KCD2 / Witcher 3 reference, never
   their assets). ADR 0018's fantasy/anime finish is withdrawn for all art; its accessibility rule
   (gameplay state readable by value and shape, never by saturation alone) carries over.
2. **Humans are built on the MakeHuman CC0 base mesh through MPFB 2** in headless Blender
   (`tools/assets/realistic_humans/`, build time only). This reverses the July "own mesh only"
   rule for humans. MakeHuman's base mesh, shape targets, rig weights, eyes, brows, lashes, teeth,
   skins and hair are CC0; MPFB's GPL code never ships. Each character is a spec
   (`specs.py`): macros (sex, age, muscle, weight, proportions), detail targets for an individual
   face and build, complexion, grooming and wardrobe.
3. **The shared 41-bone rig and 76 clips stay.** The body is posed into the rig's T-pose and
   bound with MakeHuman's authored weights mapped onto the shared bones; joints move onto the
   body without changing any bone orientation, so every clip keeps its meaning.
4. **Surfaces are generated from the fitted body**: rest-space position maps drive complexion
   (tan, flush, soot), pores and age lines on the MakeHuman albedo; beards are alpha-tested fur
   shells; card hair is recoloured per character.
5. **Clothing is constructed, not painted**, from `history/dossiers/dailylife/clothing-and-status-markers.md`:
   linen shirt and braies, gored wool tunic with belt, purse and knife, separate hose, turned
   ankle boots, forge apron, hood with shoulder cape, quilted aketon, riveted mail haubergeon,
   kettle hat. Garments sit on per-slice convex hulls of the body (cloth spans hollows), skirts
   are lofted and flared, hems are bound, and weave/leather/mail maps tile at world scale.
6. **Kalev is fully modular**: every garment is a `CharacterWearable` fitted to his body, in the
   existing slots (torso, outerwear, legs, feet, head), and hides the body regions it covers;
   weapons keep the `handslot` sockets. Named outfits (forge, street, travel, armed) are data.
7. **Tiers from ADR 0016 still apply**: Kalev and core cast are Tier 0 (60k triangles, 2048 px)
   and get extra polish; other named NPCs Tier 1; crowds must later be derived from the same
   pipeline with LODs, not from the retired procedural bodies.

## Alternatives

- **Keep improving the procedural generator.** Rejected: primitive construction tops out far
  below the reference; months of tuning already showed diminishing returns.
- **Extend the image-to-3D reconstruction to the cast.** Rejected: poor deformation topology,
  one-off characters, painted-on hair, and an EU-excluding model licence.
- **Buy or download finished character packs.** Rejected: no consistent rig, style or period
  accuracy, and the maintainer wants in-repo, parameterised generation.

## Consequences

- Retired scope (equivalent cost): new human work in `tools/generate_hero_body.py` PartBuilder
  bodies, `tools/assets/kalev_rebuild/` reconstruction and storybook human finishing stops;
  existing assets stay live only until each character is migrated to this pipeline.
- Build machines need MPFB and the MakeHuman CC0 system assets:
  `tools/assets/realistic_humans/install_mpfb.sh` (pinned SHA-256s).
- Remaining quality work is tracked in `docs/CHARACTER_GENERATION.md` (realistic humans section):
  cloth simulation and wrinkle maps, per-character hair grooms, hand/finger articulation, facial
  animation and crowd LODs.
