# WB-01: ADR 0023 - terrain relief becomes gameplay, not decoration

Board row: **R-973**. Priority: high. Depends on: none. Gate for R-974..R-976.

## Player-facing goal

None directly. This row is the scope gate that lets Reval stop being flat.

## Why this is needed

`docs/MAP_AUTHORING.md` currently states that authored elevation "does not change 2D collision,
navigation, stable IDs, transition placement, or save identity", and `MapBlueprintCompiler`
rejects any `ground_elevation` outside `0.0 .. 8.0`. Two consequences:

- A **ditch, moat cut, quarry floor, cellar mouth or sunken lane cannot be expressed at all**,
  because negative height is invalid.
- Toompea is authored at `elevation=2.8` units (about 2.4 m) although it is a limestone hill
  standing roughly 20-30 m above the Lower Town (`docs/HISTORICAL_AUDIT.md` H01, H12, and H11's
  "sandstone cliff 5-8 m above historical harbour ground").

Making relief authoritative changes navigation, movement, collision, camera and save-relevant
position semantics. Under `AGENTS.md` that is a scope change and needs an ADR before any code.

## Deliverable

`docs/adr/0023-terrain-relief-as-gameplay.md` with the standard Status / Context / Decision /
Alternatives / Consequences sections, deciding at minimum:

1. **Representation.** A per-cell signed height field compiled from authored relief primitives,
   participating in the canonical `MapDefinition` fingerprint, with a stated height range (propose
   `-8.0 .. +32.0` world units) and a stated vertical quantisation.
2. **Authority split.** Which layer owns height: the compiled definition is authoritative; the
   existing view-layer `MapViewMeshBuilder.ensure_height_field` procedural relief becomes a
   *detail* modulation on top of it, not a second source of truth. Boats, penned fauna, urban fauna
   and scatter already consume the view field and must keep working.
3. **Gameplay rules.** Maximum walkable slope, slope-dependent movement cost, what counts as an
   impassable face, and whether ledges are climbable (defer to `map_climbable_props.gd` or not).
4. **Navigation.** Whether the authoritative navigation stays a 2D region with slope-derived
   obstructions, or becomes a 3D navigation mesh. Record the cost of each; the 2D-plus-obstruction
   route is the cheaper default and should be justified or rejected explicitly.
5. **Save and determinism.** Confirm that save identity stays `{location_id, object_id}` plus
   global cell/sub-cell, and that height is derived, never persisted.
6. **Migration.** Existing `elevation_area` / `elevation_ramp` statements and all
   `r454.*` profile IDs stay valid and lower into the new representation with identical IDs.
7. **Removed scope, named explicitly.** Required by `AGENTS.md`. Candidate: the tower-capture,
   naval and castle-building mini-games already parked as out-of-scope stay parked permanently, or
   an equivalent-cost item the maintainer names. The ADR must state the removal, not gesture at it.

## Allowed files

`docs/adr/0023-terrain-relief-as-gameplay.md`, `docs/tasks/world/WB-01_adr_relief_as_gameplay.md`,
`TODO.md`.

## Constraints and non-goals

No code, no `.rrmap` change, no threshold change in this row. Do not amend ADR 0009 or ADR 0010;
reference them. Do not pre-empt the coastal ladder in **R-951** - the ADR must state how the ladder
lowers into the new representation without re-authoring `r454.harbor_*` IDs.

## Verification

`python3 tools/generate_active_docs_report.py --check`; maintainer acceptance recorded in the ADR
`Status` section with an ISO date; a second reviewer confirms the removed scope is named and costed.

## Doc updates

Link the ADR from `docs/MAP_AUTHORING.md` and from this pack's README row table.

## Status (2026-09-26)

Drafted: [`docs/adr/0023-terrain-relief-as-gameplay.md`](../../adr/0023-terrain-relief-as-gameplay.md),
status *Proposed*. Open items for this row: maintainer acceptance with an ISO date in the ADR
`Status` section, and a second reviewer confirming the removed scope (tower-capture, naval and
castle-building mini-games made permanently out of scope) is named and costed.
