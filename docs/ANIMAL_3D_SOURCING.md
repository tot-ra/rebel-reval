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

A first build-time experiment with evolved muscle-driven gaits (planar MuJoCo, CMA-ES) is described in [Muscle-driven procedural locomotion](./SYSTEMS/MUSCLE_LOCOMOTION.md): planar quadruped and biped walk.

## What the repo already has (humans vs animals)

- **Humans:** MPFB (MakeHuman plugin for Blender, v2.0.17, CC0 MakeHuman system assets) builds bodies headless in Blender: `tools/assets/realistic_humans/install_mpfb.sh`, `build_human.py`, `specs.py`. MPFB makes the base body and its weights; the bones are then moved onto a shared 41-bone motion rig with 76 CC0 KayKit clips, so every human shares one clip library (ADR 0022). Build-time only; the game never loads MPFB.
- **Animals:** the same idea already exists by hand, without a parametric body generator: `tools/assets/medieval_animal_rigs.py` (shared low-cost quadruped rig plus per-species rigs for cattle, goat, sheep, horse, pig, dog, bear, elk and shared livestock clips), `mammal_limb_anatomy.py` and `import_realistic_mammals.py` (measured limb chains, foot-contact gait settings), `build_bird_gaits.py` (compact armature plus Idle/Walk for fowl), `build_horse_source.py` (procedural loft). Mammals therefore already share a rig and clip contract. The gaps are birds (fly, perch, land) and the missing species.
- **No MPFB equivalent for animals** was found. MPFB/MB-Lab/CharMorph are human generators. [SMAL](https://awol.is.tue.mpg.de/license.html)-type parametric animal models exist in research but their license is non-commercial. Blender's built-in Rigify ships animal metarigs (cat, wolf, horse, shark, bird) as a skeleton and control-rig starting point.

## Generating instead of downloading (deep dive, 2026-10-07)

Everything below comes from search results, not from running the tools. Papers and vendor claims are unverified; benchmarks are the authors' own. Licenses must be read on the official repository or model card.

### Three separate problems

"Make an animated animal" is three problems with different maturity:

| Problem | Maturity | Best current tools |
|---|---|---|
| 1. Mesh (shape and texture) | Good for prototypes, weak for species accuracy and anatomy; the repo's Hunyuan trials already showed this | Sketchfab CC0/CC BY remains safer; AI meshes need cleanup |
| 2. Rig and skin weights | **Now largely automatic** | See below |
| 3. Motion (clips) | Research-grade for animals; practical route is retargeting or procedural gaits | See below |

### Auto-rigging of arbitrary meshes (problem 2)

- [UniRig](https://github.com/VAST-AI-Research/UniRig) (SIGGRAPH 2025, VAST/Tripo): autoregressive skeleton prediction plus skinning-weight prediction for humans, animals and fictional creatures. Code and skeleton/skinning checkpoint are reported MIT; training data Articulation-XL2.0 is CC BY 4.0. Needs a GPU.
- [MagicArticulate](https://github.com/Seed3D/MagicArticulate) (CVPR 2025) and [Puppeteer](https://arxiv.org/abs/2508.10898) (NeurIPS 2025, rigging plus animation): same family; Puppeteer's license is not confirmed (only a third-party mirror said Apache-2.0).
- Commercial: [Tripo auto-rig](https://developers.tripo3d.ai/en/docs/animations-rig) lists biped, quadruped, hexapod, octopod, avian, serpentine and aquatic skeleton types with 90+ presets. [Meshy](https://www.meshy.ai/tutorials/character-auto-rigging-workflow) offers Humanoid, Quadruped Dog and Smart Rig (beta), with fewer quadruped animations. Mixamo is humanoid-only. These are vendor claims; no head-to-head animal test was found. Check the output license before committing anything (Meshy free plan is CC BY 4.0 per its own pages).

Implication: the manual skinning step in the recommendation can be replaced by UniRig-class tools, then corrected in Blender. Output skeletons are model-specific, so a retarget or "snap to archetype" step is still required.

### Motion from a skeleton alone (problem 3), the "generic system" you asked about

Yes, such systems exist, in two families.

**Learned, skeleton-conditioned (research):**
- [AnyTop](https://arxiv.org/html/2502.17327v1) (SIGGRAPH 2025): a diffusion model that generates motion given only a skeleton's topology (plus joint text descriptions); trained on the Truebones Zoo, it reportedly generalises to unseen skeletons and works from as few as three examples per topology. Closest match to "from the skeleton, work out how this organism moves".
- [OmniMotionGPT](https://arxiv.org/abs/2311.18303) (CVPR 2024): text to animal motion from limited data (AnimalML3D, 1,240 sequences, 36 animals). [X-MoGen](https://arxiv.org/pdf/2508.05162) and [Topology-Agnostic Animal Motion Generation](https://arxiv.org/pdf/2512.10352) extend this to many morphologies.
- [AnimateAnyMesh](https://arxiv.org/abs/2506.09982) (ICCV 2025) and AnimateAnyMesh++: feed-forward text-driven animation of an arbitrary mesh in seconds; vertex-level, so it does not give you a clean skeleton clip. Quadrupeds were 10 of 50 test models in the successor paper.
- [MoCapAnything](https://arxiv.org/abs/2512.10881) / [V2](https://www.alphaxiv.org/abs/2604.28130): from a monocular video plus any rigged asset it outputs BVH-style animation. This turns **nature footage of real animals into clips for our rigs**, and it supports quadrupeds and birds. Also introduces the Truebones Zoo clip set (1,038 clips).
- Video to animal 3D: SMAL-based reconstruction ([Creatures Great and SMAL](https://arxiv.org/html/1811.05804v1), [Animal Avatars](https://arxiv.org/pdf/2403.17103), [4D-Animal](https://openaccess.thecvf.com/content/WACV2026/papers/Zhong_4D-Animal_Freely_Reconstructing_Animatable_3D_Animals_from_Videos_WACV_2026_paper.pdf)); SMAL covers quadrupeds from a small scan set, so use it for pose/gait capture rather than shapes.
- Learned controllers: [Mode-Adaptive Neural Networks for Quadruped Motion Control](https://www.research.ed.ac.uk/en/publications/mode-adaptive-neural-networks-for-quadruped-motion-control/) (SIGGRAPH 2018) learns responsive dog locomotion from mocap. Heavy for a game with dozens of species.

**Procedural, no data (shippable):**
- Chris Hecker's Spore system ("[How To Animate a Character You've Never Seen Before](https://archive.org/details/GDC2007Hecker)", GDC 2007; SIGGRAPH 2008): IK-based animation defined relative to the body, working on creatures with any limb count. Primary source not read; summaries in [Game Anim](https://www.gameanim.com/2008/08/10/spore-animation-white-paper/).
- [Procedural Locomotion of Multi-Legged Characters in Dynamic Environments](https://liris.cnrs.fr/Documents/Liris-5511.pdf): gait/tempo manager and footprint planner from a static skeleton with no mocap. This is the cleanest published recipe for "give a skeleton, get walk/trot/run".
- Template mapping (a patent describes aligning torso and limbs to a template quadruped and scaling) and CPG gait oscillators from robotics for gait timing.

**Datasets:** [Truebones Zoo](https://truebones.gumroad.com/p/free-truebones-zoo-over-75-animated-animals-with-textures-in-fbx-format) is a free 75+ animal FBX set with animations, the same data AnyTop trains on. **Its license was not found**; the vendor's terms must be read before any commercial or in-repo use.

### Indie practice

No single dev blog covers a multi-species pipeline. What the sources show: quadruped clips start from video reference or mocap and get reshaped by hand ([MoCap Online guide](https://mocaponline.com/blogs/mocap-news/creature-animation-games-guide)); [Blender Studio's Project DogWalk](https://studio.blender.org/blog/animations-for-dogwalk/) documents bone-scaling and glTF export problems with Godot; a Godot devlog ([Twocents](https://twocentstudios.com/2024/03/28/indie-game-devlog-03/)) shows AnimationTree/AnimationPlayer read-only quirks for Blender exports; procedural motion is the common indie shortcut ([Wayline](https://www.wayline.io/blog/procedural-animation-indie-dev-secret-weapon)); [MonRig](https://monrig.com/) is a commercial tool that places a starter skeleton by body role and bakes clips.

### What I can and cannot do from this session

- Can: write the procedural gait generator (Python or GDScript) that reads each archetype skeleton, detects legs and spine, and produces idle/walk/trot/run/attack/hit/death clips as glTF animations or runtime code; write Blender scripts for retarget and import; build the license manifest and validators.
- Cannot here: run UniRig, AnyTop, MoCapAnything or any other model (no GPU; this session has no Blender or Godot, and Hugging Face and GitHub model hosts are blocked); judge animation quality by eye, since I cannot render clips. Visual acceptance needs a maintainer or a machine with Godot.

## Recommendation

Revised after the deep dive: the main lever is **procedural and retargeted motion on a small set of archetype rigs**, not downloaded clips. A hybrid, in this order:

1. **Define archetype rigs.** Decide five to seven archetypes covering the 30-mammal and 30-bird catalogs. Author or adopt one rig and one clip set each. Required clips: idle, walk, run, attack, hit, death, plus per-archetype extras (graze, sleep, fly flap, glide, land, perch).
2. **Seed clips from CC0 donors.** Pull Quaternius (wolf, dog, cat, horse, cow, eagle) and Gobkit clips as animation donors. Retarget onto archetype rigs in Blender; export one GLB animation library per archetype. CC0 means no attribution burden on the clips.
3. **Source realistic meshes from Sketchfab** with the P0-209b process: CC0 or CC BY only, pre-filter for animal-specific quality, record URL, creator, SHA-256 and edits in the manifest and `SOURCES.csv`, cap triangles and texture size, and commit only the self-contained runtime GLB.
4. **Skin each mesh to its archetype rig** (weight transfer in Blender, an auto-rigger such as UniRig followed by manual fixes, or keep the creator's rig where it is good, as with the rat). Prefer this over AI-generated meshes. If AI meshes are used, do it as a mesh source with this same rigging step.
5. **Fill the remaining clips procedurally**: an archetype-driven gait generator (walk, trot, run, graze, hit, death) following the multi-legged locomotion and Spore approach, tuned per species by leg length, stride and tempo. Optionally use MoCapAnything on public-domain nature footage, or AnyTop-style generation, as an offline clip source; clips are baked into GLB, so no ML runs in the game.
6. **Birds**: keep the procedural fallback and the existing flap and glide system; replace species one family at a time (gull, corvid, raptor, waterfowl, wader) with Sketchfab meshes on two bird archetypes (small perched songbird; large flapping/gliding bird).
7. **Species differentiation** comes from scale, texture and `catalog_plumage.gdshader`-style tinting, which already exists.

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
