# ADR 0016: Tiered character fidelity on the shared rig

**Recorded:** 2026-07-28  
**Amends:** [ADR 0007](0007-ai-generated-isometric-presentation.md) (single uniform character quality rule)

## Status

Accepted

Maintainer accept recorded 2026-07-28 for the frozen budget table in
[`docs/VISUAL_FIDELITY_PLAN.md`](../VISUAL_FIDELITY_PLAN.md) and enforcement in
`tools/verify_asset_lint.py` via `tools/character_fidelity_tiers.py`.

## Context

[ADR 0007](0007-ai-generated-isometric-presentation.md) requires one shared low-poly humanoid
rig and animation library so NPC production stays fast and consistent. Since
[ADR 0015](0015-default-third-person-camera.md), the default camera is an over-the-shoulder
perspective view: Kalev, Mart, and named cast members are visible in closeup, while battle
and crowd scenes must still scale to hundreds of actors.

A single mesh and shader budget for every humanoid either caps hero quality or makes crowds
too expensive. The measured gap in [`docs/VISUAL_FIDELITY_PLAN.md`](../VISUAL_FIDELITY_PLAN.md)
shows shared-rig bodies at roughly 8.9k-9.5k triangles with flat per-part colors and no UVs.

## Decision

1. Keep **one shared skeleton and one animation library** for all humanoid characters (ADR 0007
   core is intact).
2. Introduce **three fidelity tiers** that differ in mesh detail, material/shader set, texture
   resolution, and runtime instancing method:

| Tier | Who | Triangle cap (LOD0) | Texture cap | Shader set | Instancing |
|---:|---|---:|---:|---|---|
| **0 — Hero** | Kalev and core named cast (Mart, Aita, Kaja, Henning, Jürgen, Ellen; `townswoman` base for female cast) | 60,000 | 2048 px | Full PBR with skin SSS, hair, and eye shaders | `SkeletonMeshInstance3D` |
| **1 — Named NPC** | Shopkeepers, faction figures, quest NPCs (innkeeper, watchman, sergeant, danish_warrior, ...) | 56,000 | 1024 px | Shared skin shader plus per-character PBR texture/equipment swaps | `SkeletonMeshInstance3D` |
| **2 — Crowd / battle** | Uprising crowds, siege ranks, ambient townsfolk | 12,000 | 512 px | Simplified crowd PBR shader | `MultiMeshInstance3D` or VAT |

3. Assign every runtime humanoid GLB under `assets/characters/**` a tier through
   `fidelity_tier` in `tools/character_specs.py`. Garment accessories (`hero_cape.glb`,
   `hero_hat.glb`) inherit Tier 0 with a separate 1,024-triangle / 1024 px garment cap.
4. Exclude build-input GLBs (for example `kaykit_barbarian.glb`) from tier enforcement; they are
   not shipped at runtime per `docs/CHARACTER_GENERATION.md`.
5. Enforce triangle and embedded-texture caps in `tools/verify_asset_lint.py`. Shader and
   instancing rules are documented in the fidelity plan and verified by focused Godot tests as
   each tier pipeline lands (P0-146 through P0-152).

## Alternatives

- **Keep one budget for every humanoid (ADR 0007 literal).** Rejected. It blocks the hero-tier
  head/hand/hair work in P0-149 without lowering crowd density targets.
- **Separate rigs per tier.** Rejected. Animation reuse and retarget cost are the project's main
  production advantage; tiers vary detail and instancing, not skeleton semantics.
- **Defer enforcement until PBR textures ship.** Rejected partially. Triangle caps are
  enforceable today; texture caps apply once embedded images exist (P0-144+).

## Consequences

- ADR 0007 item 5 ("characters are shared low-poly rigs") now means **shared rig, tiered detail**,
  not identical mesh or shader cost.
- `tools/character_specs.py` carries `fidelity_tier` on every generated body row.
- `tools/character_fidelity_tiers.py` is the single source of frozen numeric caps; asset lint
  imports it.
- Hero and named-cast upgrades (P0-149, P0-150) must stay inside Tier 0/1 caps or require an ADR
  amendment.
- Crowd rendering (P0-152) must use Tier 2 instancing; individual `SkeletonMeshInstance3D` actors
  are not permitted above the authored concurrent-character cap in battle scenes.
