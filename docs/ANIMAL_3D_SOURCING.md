# Animal 3D model sourcing and animation strategy (2026-10-07)

Status: research and proposal. No model files were added; see [What was not done](#what-was-not-done). Scope: where to obtain realistic, animated mammals, birds and other fauna for Reval Rebel, and how to organise rigs and clips so the set can grow. Related: [Flora and fauna ledger](./FLORA_FAUNA.md), [Mammal replacement P0-209b](./reports/animal_realism_2026-09-12.md), [Bird catalogue realism](./reports/bird_catalog_realism_2026-09-12.md), [Asset storage policy](./ASSET_STORAGE_POLICY.md).

## Where we are

- Mammals: nine species (cat, sheep, dog, pig, goat, boar, fox, hare, rat) from CC BY 4.0 Sketchfab sources, with measured limb chains (P0-209b). Credits are in `assets/storybook/mammal_sources.json` and `assets/SOURCES.csv`. This is the proven pipeline and it already works.
- Birds: 30 species cataloged, only a few gull/tern/sparrow GLBs; the rest is a procedural fallback.
- The catalog targets 30 mammals and 30 birds. AI mesh generation (Hunyuan) was tried for gulls, waders and corvids and produced unreliable results, which is the problem you describe.

## Findings by source

Licenses below come from search results and my own knowledge. The target sites were blocked from this session, so **verify each license on the model's own page before importing**.

| Source | Content | Rigged / animated | License | Realism | Fit |
|---|---|---|---|---|---|
| [Quaternius LowPoly Animated Animals](https://quaternius.itch.io/lowpoly-animated-animals) | 6 animals | Death, Idle, Jump, Run, Walk | CC0 | Stylized low poly | Good as an animation donor and prototyping stand-in. FBX/OBJ/Blend, no glTF listed. A commenter reports missing clips, so open the file first |
| [Quaternius Animal Pack Vol.2 (OpenGameArt)](https://opengameart.org/content/animated-animales-low-poly) | wolf, eagle, dog, cat, piranha | yes | CC0 | Stylized | Wolf and eagle are useful archetype donors |
| Quaternius Farm Animals (itch.io, same page family) | cow, horse, pig, llama, pug | animated | CC0 | Stylized | Livestock archetypes |
| [Gobkit Free Animal Pack](https://gobkit.itch.io/gobkit-free-animal-pack) and [freebies](https://gobkit.com/freebies) | 10 + more | Shared retargetable skeleton, baked idle/attack/dead/walk, GLB | CC0 | Stylized | Only clean GLB source with attack and death; no medieval-relevant species except duck. Dead clip holds last frame |
| Kenney Animals | static low poly | no | CC0 | Stylized | Not useful here |
| [Sketchfab](https://sketchfab.com) with download and license filter | the only large source of realistic, animated, species-specific models (deer, wolf, bear, lynx, owl, eagle, heron, swan, horse, cattle) | varies per model | CC0 or CC BY mostly; some "personal use only" notes | Photoreal to high | **Primary route for realism.** Same route as P0-209b. Needs free login, per-model review, attribution rows |
| Smithsonian Open Access 3D, scanned natural history | real specimens | static | CC0 | Very high | Reference, textures, proportions; needs manual rigging |
| Paid (Fab, Unity Asset Store, TurboSquid, CGTrader, RenderHub) | many realistic rigged packs | yes | Store EULA | High | **Not usable in this repo**: it is public AGPL, and store licenses forbid redistributing source files. Could be used only if a build pipeline kept them out of Git |
| Meshy, Sloyd, other AI generators | any species | rarely | Often CC BY / account-dependent | Inconsistent | Only as a mesh source with manual rig and cleanup, as with the Hunyuan trials |
| Mixamo | humanoid only | yes | Adobe terms | n/a | Does not help animals |

Key fact: **no free source offers realistic, species-diverse, rigged animals with attack and death clips under CC0.** Realism comes from Sketchfab CC BY/CC0 meshes. Animation completeness has to come from retargeting, not from the model download.

## How games solve it

Primary sources for Rockstar and CD Projekt RED pipelines were blocked, so the following is the general industry pattern, not a verified account of any one studio. Rockstar states Red Dead Redemption 2 has around 200 species of animals, birds and fish; the count is behaviours and species, not 200 hand-built rigs.

1. **Archetype skeletons.** A handful of shared rigs (canine, feline, ungulate, rodent, large bird, small bird, waterfowl) each have one authored clip library. A new species is a new mesh skinned to an archetype skeleton, with different scale, proportions and texture.
2. **Retargeting.** Clips authored once are mapped to other skeletons through a bone map. Godot 4 supports this with `SkeletonProfile` and `BoneMap` in import settings.
3. **Procedural layers on top of clips**: foot IK on terrain, spine and head look-at, speed-scaled locomotion blending, ragdoll or physical death, additive breathing and tail noise.
4. **Behaviour reuse for variety.** Flee, graze, flock and perch states with per-species parameters make a small clip set read as many animals.
5. **Instancing for crowds.** Flocks of birds use a shared animated mesh with per-instance phase offset, or a vertex-animation texture, rather than one skeleton per bird.

## Recommendation

A hybrid, in this order:

1. **Define archetype rigs.** Decide five to seven archetypes covering the 30-mammal and 30-bird catalogs. Author or adopt one rig and one clip set each. Required clips: idle, walk, run, attack, hit, death, plus per-archetype extras (graze, sleep, fly flap, glide, land, perch).
2. **Seed clips from CC0 donors.** Pull Quaternius (wolf, dog, cat, horse, cow, eagle) and Gobkit clips as animation donors. Retarget onto archetype rigs in Blender; export one GLB animation library per archetype. CC0 means no attribution burden on the clips.
3. **Source realistic meshes from Sketchfab** with the P0-209b process: CC0 or CC BY only, pre-filter for animal-specific quality, record URL, creator, SHA-256 and edits in the manifest and `SOURCES.csv`, cap triangles and texture size, and commit only the self-contained runtime GLB.
4. **Skin each mesh to its archetype rig** (weight transfer in Blender, or keep the creator's rig where it is good, as with the rat). Prefer this over AI-generated meshes. If AI meshes are used, do it as a mesh source with this same rigging step.
5. **Birds**: keep the procedural fallback and the existing flap and glide system; replace species one family at a time (gull, corvid, raptor, waterfowl, wader) with Sketchfab meshes on two bird archetypes (small perched songbird; large flapping/gliding bird).
6. **Species differentiation** comes from scale, texture and `catalog_plumage.gdshader`-style tinting, which already exists.

Suggested first batch to prove the pipeline: wolf, deer, horse (if the catalog needs it), one raptor, one waterfowl, with all seven clip types each.

## Constraints from AGENTS.md

- The asset freeze (P0-040) restricts legacy isometric and pixel art, not 3D animals, but new production art still needs a task naming the exact files. File a task per archetype batch before importing.
- Feature documentation: when a batch lands, update `docs/FLORA_FAUNA.md`.
- Binaries under 10 MiB go in standard Git; larger ones go to Git LFS.

## What was not done

The session's network egress policy blocked quaternius.com, itch.io, sketchfab.com, poly.pizza, opengameart.org, gobkit.com, archive.org and similar hosts; only GitHub was reachable, and the session is scoped to this repository. Therefore:

- no models were downloaded or added;
- license and animation lists above for third-party packs are from search snippets and need confirming on download;
- the Rockstar/CD Projekt practices are an inferred industry pattern.

To proceed, either allow those hosts in the environment's network policy, or download the packs on a workstation and hand them over for import and retargeting.
