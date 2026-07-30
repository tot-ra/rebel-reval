# Visual Fidelity Plan - saturated high-detail fantasy/anime PBR

Companion to [`WITCHER3_REALISM_INSPIRATION.md`](WITCHER3_REALISM_INSPIRATION.md), which covers gameplay realism, and [ADR 0018](adr/0018-saturated-hdr-fantasy-anime-visual-direction.md), which governs appearance. This document covers the concrete gap between the current 3D presentation and a saturated, high-detail, painterly PBR medieval fantasy/anime look with HDR-range lighting. Backlog rows P0-140 through P0-160 in [`../TODO.md`](../TODO.md) implement the underlying fidelity pipeline.

Since [ADR 0015](adr/0015-default-third-person-camera.md) the default camera is an
over-the-shoulder perspective follow camera (not the old fixed isometric view), so character
and prop surface quality is now on-screen and close to the player. This plan targets that camera.

## Honest target

Large premium RPG and anime productions use specialized concept, modeling, surfacing, lighting, VFX, and animation teams. Reval Rebel instead uses deterministic procedural/AI-assisted production with one maintainer. We will not claim feature-film anime rendering, hand-authored AAA asset volume, or HDR10 output. The achievable target is:

> A distinctive historical fantasy/anime period drama with rich controlled color, expressive shape language, painterly PBR materials, three-scale authored detail, colorful night lighting, and HDR-range highlights compressed cleanly through AgX, while crowds and battles remain performant.

"Realism" in source briefs now means historical, anatomical, functional, scale, and material credibility. It does not prescribe pale color, photographic noise, neutral lighting, or naturalistic proportions as the final visual finish. Everything below is chosen for high visible fidelity within the frozen tier and performance constraints.

## Measured gap (updated 2026-07-30)

| Area | Current state (measured) | Consequence |
|---|---|---|
| Character textures | `heroic_humanoid.glb`: ~51k indexed tris across anatomical layers, **0 images**, 14 flat per-part color materials. mart/henning/townswoman/etc. follow the same pattern. No UVs. | Reads toy-like and cannot carry expressive face/hand detail, costume story, rich material color, or anime-influenced shape grouping - the #1 fidelity gap. |
| Post-process grade | AgX, glow, and adjustment are wired with ADR 0018 saturation, contrast, and controlled highlight values. Matched day/night third-person and top-down captures live under `docs/reports/images/adr0018_calibration/`. | Continue opportunistic hero-asset migration; weather-state matched plates remain optional follow-up. |
| Renderer | `project.godot`: `renderer/rendering_method="gl_compatibility"`. | No SSAO/SSIL/SDFGI/SSR/volumetric fog and no established HDR10/wide-gamut output. This is a ceiling on advanced light/VFX, not permission to mislabel SDR output as display HDR. |
| Props / animals | Forge & furniture GLBs carry 1–3 images (albedo only); animal GLBs 1 image. | Flat, unlit-looking surfaces under otherwise-good dynamic lighting. |
| LOD / crowds | Shared rig has no `visibility_range`/LOD; no `MultiMeshInstance3D` for characters. | 40k-tri characters do not scale to battle-sized counts. |
| Camera | Third-person perspective exists; no `CameraAttributes` (no DoF, no exposure). | No cinematic depth or exposure control in closeups. |

**Strengths to preserve:** the environment pipeline is already strong - procedural building
shaders with normal maps, real day/night, weather, sky dome, water sky-reflection, and
height-biased morning fog. This plan does not rebuild that; it lifts characters, props, grade,
and lighting up to the same bar.

## Three-tier character model (maintainer direction, 2026-07-28)

ADR 0007 mandates a single shared low-poly rig with no bespoke authoring. The maintainer has
widened this to a **fidelity-tiered** model - high quality where the player looks closely, cheap
and plentiful where they do not. Ratified in [ADR 0016](adr/0016-tiered-character-fidelity.md)
(task **P0-140**).

| Tier | Who | Fidelity | Pipeline |
|---|---|---|---|
| **Tier 0 - Hero** | Kalev, core named cast (Mart, Aita, Kaja, Henning, Jürgen, Ellen) | Highest: higher poly head/hands, sculpted normal detail, per-character PBR textures, hair cards, skin/eye shaders | Bespoke pass on top of the shared rig; budget and shader set frozen below |
| **Tier 1 - Named NPC** | Faction figures, shopkeepers, quest NPCs | Medium: shared rig + per-character PBR texture/equipment swaps, shared skin shader | Shared rig + texture pipeline (P0-145) |
| **Tier 2 - Crowd / battle** | Uprising crowds, siege ranks, ambient townsfolk | Good-but-cheap: LOD'd shared rig, batched via MultiMesh/VAT, simplified crowd shader, deterministic per-instance variation | Procedural variation generator + instancing (P0-151/152/153) |

All three tiers share one rig and one animation library (the ADR 0007 core is intact); they
differ in mesh detail, material/shader set, and how they are instanced.

### Frozen per-tier budget table (P0-140)

Enforced by `tools/verify_asset_lint.py` through `tools/character_fidelity_tiers.py`.
`fidelity_tier` on each `tools/character_specs.py` row assigns runtime GLBs to a tier.

| Tier | Triangle cap (LOD0) | Texture max | Shader set | Instancing | LOD notes |
|---:|---:|---:|---|---|---|
| 0 Hero | 60,000 | 2048 px | `full_pbr_skin_hair_eyes` | `skeleton_mesh_instance` | LOD1/LOD2 optional; P0-151 |
| 1 Named NPC | 56,000 | 1024 px | `shared_skin_plus_pbr_swaps` | `skeleton_mesh_instance` | LOD1/LOD2 optional; P0-151 |
| 2 Crowd / battle | 12,000 | 512 px | `crowd_simplified_pbr` | `multimesh_or_vat` | LOD1 ~50%, LOD2 ~20% of LOD0; P0-151 |

Distance LOD switching (P0-151, `SharedCharacterRig`): LOD0 full meshes fade out by 18 world
units; LOD1 covers 14-48 units; LOD2 takes over from 44 units onward. Decimated GLBs live beside
each body as `<body>_lod1.glb` / `<body>_lod2.glb`; triangle fractions are recorded in
`assets/characters/shared/character_lod_manifest.json` (authored ~50% / ~20% of LOD0).

Triangle caps sum indexed triangle primitives across every skinned layer exported into the
GLB (`anatomical_layers=True` bodies today land near 51k-55k tris).

Garment accessories (`hero_cape.glb`, `hero_hat.glb`): 1,024 triangles, 1024 px texture cap.

Build-input GLBs (`kaykit_barbarian.glb`) are excluded from tier lint.

Measured 2026-07-28 indexed LOD0 bodies: heroic_humanoid 51,312; mart 51,744; henning/sergeant
55,248; innkeeper 51,024; watchman 51,744; danish_warrior 52,512; townswoman 51,456 - all within
Tier 0/1 caps. Garments: cape 720, hat 528.

## Workstreams

### A. Rendering foundation (unblocks everything, tier-independent)
- **P0-141** Post-process grade: AgX, controlled glow/bloom, and saturated color adjustment wired into the day/night cycle; ADR 0018 values are frozen in ART_BIBLE v2. Scene-referred highlights work on GL Compatibility today, but HDR10/wide-gamut output is not claimed.
- **P0-142** Renderer evaluation spike: measured Forward+ vs Mobile vs GL-Compat comparison
  (frame time on min hardware + fidelity captures) with a maintainer decision. Fits ADR 0007's
  "P0-038 may escalate renderer choice" clause.
- **P0-143** Camera attributes: subtle DoF + exposure per camera mode (off in top-down).

### B. Character PBR pipeline (serves all tiers)
- **P0-144** UV-unwrap + material-texture slots on the shared body mesh (foundation; today it is
  untextured).
- **P0-145** AI character-surface texture generator: albedo+normal+roughness+AO for skin, cloth,
  leather, metal, hair zones, with SOURCES.csv provenance.
- **P0-146** Skin + eye shaders (subsurface/wrap-lit skin; specular eyes).
- **P0-147** Cloth/leather/metal PBR material tuning (retire flat/unshaded per-part colors).
- **P0-148** Hair/beard upgrade (hair-card or shell geometry + hair shader).

### C. Hero tier (Tier 0)
- **P0-149** Kalev hero-tier upgrade to the frozen Tier-0 budget.
- **P0-150** Core named-cast hero upgrades (extends existing P2-004).

### D. Crowd / battle tier (Tier 2, procedural + performant)
- **P0-151** Character LOD system (LOD1/LOD2 + distance switching; follows the `forge_cat` LOD precedent).
- **P0-152** Crowd instancing/batching (MultiMesh or vertex-animation-texture crowd renderer).
- **P0-153** Procedural NPC variation generator (height/build/skin/garment variation, no clones).
- **P0-154** Crowd performance budget + battle-scene benchmark on min hardware.

### E. Prop / environment fidelity
- **P0-155** Hero-prop ORM pass (normal+roughness+AO on anvil/furnace/bellows/chests), with macro silhouette, meso construction, micro craft, and saturated material-family review.
- **P0-156** Animal GLB PBR pass (normal/roughness for cattle/pig/sheep/horse) with anatomically credible silhouettes and expressive painterly coat grouping.
- **P0-157** Wear/grime/blood decal system (battle aftermath + environmental storytelling), concentrated by use and exposure rather than uniform grunge.

### F. Fauna fidelity (birds, wild mammals, livestock, pets)
Fauna follows the same tier logic as characters: **close** fauna (the forge cat, penned livestock
the player stands beside) is Tier-1 quality; **ambient/distant** fauna (birds in flight, wild
mammals fleeing at map margins) is Tier-2 - cheap, LOD'd, and instanced, but still lit rather than
flat. Current state: birds and wild mammals are 100% procedural `SurfaceTool` vertex-color meshes
with no textures or normals; livestock GLBs are albedo-only; the forge cat (textured GLB + LOD1/LOD2)
is the quality bar to match.
- **P0-158** Procedural fauna shading uplift: give the bird and wild-mammal meshes lit materials with
  soft normals (feather/fur response), retiring flat unshaded vertex color so they react to the sun and grade.
- **P0-159** Fauna LOD + flock/herd instancing: LOD distance switching for fauna meshes and MultiMesh
  batching for bird flocks and mammal groups, reusing the P0-152 crowd path and the `forge_cat` LOD precedent.
- **P0-160** Fauna GLB PBR contract: require re-rendered fauna GLBs (the P2-034–P2-041 birds, plus
  livestock) to carry normal + roughness, enforced by asset lint, so the bird migration lands textured, not flat.
- (Livestock albedo→PBR is **P0-156**; the forge cat already meets the bar.)

## Sequencing

1. **Immediate, cheap, high-impact:** P0-141 (grade), P0-155/P0-156 (prop/animal ORM) - visible
   jump with no renderer or ADR dependency.
2. **Foundation:** P0-140 (tier ADR, done), P0-144 (UVs), P0-142 (renderer decision).
3. **Character quality:** P0-145 → P0-146/147/148 → P0-149/150 (hero), and P0-151/152/153/154 (crowd).
4. **Polish:** P0-143 (camera), P0-157 (decals), tuned against the P0-142 renderer decision.

## Guardrails

- No task changes a map fingerprint or the flat logic plane (ADR 0007 core).
- History governs form; ADR 0018 governs expressive color, shape emphasis, detail, light, and effects. Do not use fantasy styling to conceal unsupported forms.
- Every hero/landmark brief identifies macro, meso, and micro detail and proves the relevant top-down, third-person, and close-camera reads.
- Every generated texture/mesh gets a `SOURCES.csv` provenance row and passes `tools/verify_asset_lint.py`.
- Tier budgets (poly/texture/shader) are frozen in the P0-140 tier spec and enforced by asset lint. High detail must fit those budgets and collapse cleanly through LOD/mipmaps.
- Highlight hue and texture must survive AgX; bloom is selective and screen UI remains unaffected.
- Performance is gated on minimum hardware; crowd counts have a deterministic cap.
