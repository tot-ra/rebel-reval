# ADR 0023: Terrain relief becomes gameplay, not decoration

## Status

**Proposed, 2026-09-26. Awaiting maintainer acceptance.** Task: WB-01 (board R-973). Gates WB-02
(R-974), WB-03 (R-975) and WB-04 (R-976). No relief code may land until this line records the
maintainer's acceptance with an ISO date.

## Context

Reval stands on relief: Toompea is a limestone hill roughly 20-30 m above the Lower Town
(`docs/HISTORICAL_AUDIT.md` H01, H12), the harbour cliff drops 5-8 m (H11), and the town wall had
ditches and causeways. The map pipeline cannot express any of that:

- `map ... elevation=N` is a single datum in `0.0 .. 8.0` world units that the 3D view tapers to zero
  over the outer 10 cells (`MapViewMeshBuilderTerrain.elevation_factor`). Toompea uses `2.8`
  (about 2.4 m).
- `grade`, `elevation_area` and `elevation_ramp` (R-454, `r454.*` IDs on nine urban maps) are parsed,
  validated to `-8 .. 8` and carried on `MapDefinition.elevation_profiles`, but **no runtime or view
  code evaluates them**. They are annotations; today they contribute zero height.
- The rendered ground is `datum * edge_taper + procedural noise`, flattened under buildings,
  transitions and water. It lives only in the view layer (`MapViewMeshBuilder.ensure_height_field`),
  so collision, navigation and the player rig stay on a flat plane.

A ditch, moat cut, quarry floor or sunken lane cannot be authored, and nothing that depends on the
ground height can be tested headless. Making relief authoritative changes navigation, movement,
collision, camera and position semantics, which is a scope change under `AGENTS.md`.

## Decision

1. **Representation.** Each map compiles a per-cell signed relief field from ordered, ID-first
   relief primitives (`relief_hill`, `relief_ridge`, `relief_ditch`, `relief_terrace`,
   `relief_cliff`, `relief_noise`). The field is stored on `MapDefinition`, is part of the canonical
   fingerprint, and is sampled at cell centres. Total ground height is
   `datum(position) + relief(position)`, where `datum` is the existing `elevation=` value with its
   existing 10-cell edge taper. The allowed total range is **-8.0 .. +32.0 world units** (about
   -7 m .. +27 m). Every compiled cell value is quantised to **1/64 world unit** so fingerprints do
   not depend on float summation noise.
2. **Authority split.** The compiled definition is the single source of truth for ground height.
   `MapViewMeshBuilder.ensure_height_field` uses it as the base and keeps its procedural noise, pad
   flattening and water recess only as sub-cell *detail*. Boats, penned and urban fauna, scatter and
   terrain details keep their current call sites through the view field.
3. **Gameplay rules** (implemented by WB-03, R-975). The maximum walkable slope is **35 degrees**
   between 4-neighbour cell centres. Movement speed scales by `cos(slope)` up to that limit. A face
   steeper than the limit is impassable. Where it was not authored with `relief_cliff`, it raises
   the warning `MAP_RELIEF_SLOPE`. Ledges are not climbable through relief. Climbing stays with
   `map_climbable_props.gd`.
4. **Navigation.** Authoritative navigation stays a **2D region**. Cells whose slope exceeds the
   walkable limit become obstructions. A 3D navigation mesh is rejected for now. It would duplicate
   `MapVerification.is_walkable_cell`, break the headless flood-fill audits every map gate relies on,
   and cost a navmesh bake per location that ADR 0019 streaming (WB-07) has not budgeted.
5. **Save and determinism.** Save identity stays `{location_id, object_id}` plus the global cell and
   sub-cell. Height is always derived from the compiled field and is never persisted. The same
   blueprint compiles to the same field bit for bit.
6. **Migration.** `elevation=`, `grade`, `elevation_area` and `elevation_ramp` stay valid, and every
   `r454.*` ID is preserved. Legacy profiles lower into the new representation with **zero relief
   contribution**, because that is what they render today. This keeps compiled height unchanged for
   every map that authors no new statement. WB-04 (R-976) turns individual `r454.*` profiles into
   relief primitives when it re-authors a map, and states each change. The coastal ladder of
   **R-951** lowers the same way: its `r454.harbor_*` IDs keep their meaning as annotations until a
   task re-authors the harbour relief.
7. **Removed scope.** The tower-capture, naval and castle-building mini-games, listed in `AGENTS.md`
   as "need an ADR first", become **permanently out of scope** for Acts 1-3 and are no longer
   eligible for a future ADR. Cost freed: each was a separate interaction mode with its own UI, rules
   and content. That is at least the combined size of WB-02..WB-04 (relief compiler, traversal and
   re-authoring three maps). Relief also absorbs the one playable part of castle building that the
   story needs: reading walls, ditches and gates as terrain.

## Alternatives

- **Keep relief view-only and fake height in the camera.** Rejected: collision and navigation would
  disagree with what the player sees on a 20 m hill, and nothing could be tested headless.
- **Import a heightmap image per map.** Rejected: it is not diffable, carries no stable IDs, and
  cannot be reviewed line by line like `.rrmap`.
- **3D navigation mesh now.** Deferred (Decision 4) until streaming budgets exist.
- **Evaluate legacy `elevation_area`/`elevation_ramp` as real height.** Rejected for migration: it
  would silently change nine maps with no review, which the no-regeneration parity rule forbids.

## Consequences

- WB-02 bumps the map compiler version and adds four stable diagnostics: `MAP_RELIEF_RANGE`,
  `MAP_RELIEF_SLOPE`, `MAP_RELIEF_SEAM` and `MAP_RELIEF_UNDER_BUILDING`.
- Physical seams (non-`travel` reciprocal transitions) must agree on height at the shared edge.
  Because the datum tapers to zero at the border, legacy maps agree by construction.
- `docs/MAP_AUTHORING.md` no longer says elevation is view-layer only once WB-03 lands. Until then,
  compiled relief is authoritative data that gameplay does not yet read.
- References, not amendments: [ADR 0009](0009-map-blueprint-authoring-architecture.md) (blueprint
  authoring) and [ADR 0010](0010-large-map-runtime-chunking.md) (chunking) remain in force. Chunks
  consume the same compiled field and never persist it.
