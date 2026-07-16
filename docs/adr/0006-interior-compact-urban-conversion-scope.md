# ADR 0006: Interior and compact urban map conversion scope expansion

**Reference:** programmatic map pipeline conversion after P0-040 style gate and P0-034 migration matrix  
**Recorded:** 2026-07-16

## Status

Accepted (maintainer scope expansion on 2026-07-16)

## Context

P0-040 approved the clean-painted visual profile and P0-043 delivered the production map-definition contract. P0-042 proved deterministic programmatic assembly for outdoor courtyard geometry. The migration matrix marks forge, district shells, market civic interiors, guild hall placeholders, and compact urban research scenes as `convert`, while harbor and world shells remain archived.

The original conversion plan limited active production work to Kalev's smithy and one connected Lower Town exterior until slice parity passed. A maintainer explicitly expanded scope to convert all retained interior and compact urban scenes onto the shared programmatic pipeline as either production maps or `active=false` prototypes, without activating archived campaign areas or editing the active transition manifest until P2-020.

## Decision

Convert interior and compact urban scenes using shared primitives under `scripts/map/`:

- room floor and wall materials;
- doorway gaps and transition rects;
- stairs and furniture or forge props;
- roof or foreground fade volumes;
- interaction anchors.

Rules:

1. **No legacy diamond TileSets** in converted scenes. Legacy isometric TileMap layers are replaced by declarative definitions and procedural renderers.
2. **Stable scene, spawn, and anchor IDs** are preserved or aliased (`main` remains a temporary forge cutover alias).
3. **Production scope** stays limited to `loc.kalev_smithy` and the bounded Lower Town exterior until P2-020. Other converted scenes are `scope=prototype`, `active=false`.
4. **Harbor warehouse interior** may be verified as an inactive prototype derived from archived markdown references. Harbor district activation remains out of scope.
5. **No new raster production assets**. Use approved clean-painted procedural modules and existing greybox references only.
6. Each converted group ships automated coverage, reachability, anchor, and collision parity tests plus deterministic visual captures where the harness supports them.

Equivalent scope removal: deferred mass activation of center, north, harbor, Toompea, world, castle, grove, and campaign-event playables remains explicitly out of scope until separate approval artifacts land.

## Alternatives

### Wait for P2-021 parity before any interior conversion

Rejected. Maintainer expansion authorizes pipeline and prototype conversion now while keeping activation frozen.

### Hand-edit legacy `.tscn` TileMaps to orthogonal tiles

Rejected. Conflicts with P0-042/P0-043 direction and preserves the wrong authoring model.

### Activate all converted prototypes immediately

Rejected. Violates one-district campaign boundary and `AGENTS.md` scope-change rule.

## Consequences

- Shared interior factory and verification helpers live beside the outdoor spike code.
- Forge and Lower Town production conversions proceed under P2-018 and P2-019 tasks.
- Market civic, guild hall, north quarter, and harbor warehouse ship as inactive prototypes with catalog guards unchanged.
- Commits land in small scene groups with tests and documentation updates.
- P2-020 remains the only task permitted to edit `content/transitions/active_destinations.json`.
