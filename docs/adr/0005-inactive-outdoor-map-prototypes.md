# ADR 0005: Verify outdoor concepts as inactive prototypes

**Reference:** outdoor map conversion packages P0-047 through P0-050
**Recorded:** 2026-07-16

## Status

Accepted

## Context

The scene inventory and `docs/MAP_CONVERSION_PLAN.md` classify the legacy harbor, world, castle, sacred-grove, and campaign-event `.tscn` shells as archive material. The approved campaign and vertical slice remain limited to Kalev's forge and one dense Lower Town district. `AGENTS.md` requires an equivalent scope removal and a separate approval artifact before any new playable area can enter production.

The legacy shells contain little or no executable geometry, while their Markdown and reference images still contain useful layout relationships. Those relationships can be preserved and mechanically verified without making the locations playable, connecting transitions, or committing them to the campaign.

## Decision

Create declarative, procedural **verified non-playable prototypes** for the named outdoor concepts in four packages:

1. coast and harbor;
2. villages and monasteries;
3. castles and fortified locations;
4. wilderness and campaign events.

Every prototype must use `scope = prototype` and `active = false`. It may expose a stable developer inspection spawn, but it must not declare an active destination, edit `content/transitions/active_destinations.json`, alter Start flow, enter release traversal, or replace an archived legacy `.tscn` shell.

This decision is not approval for a new playable area, campaign chapter, open world, army-battle system, or travel layer. No equivalent scope removal is required because no playable scope enters production. Activation of even one prototype requires a new scope-change ADR that names equivalent scope removal and a strict TODO task for the cutover.

Existing images are layout references only. Captures must be rendered from procedural geometry and the approved clean-painted rules. Historical plausibility is limited to shared material and construction families; legacy supernatural, faction, NPC, and quest claims are not imported as canon.

## Alternatives

### Convert archived scene shells directly

Rejected. Direct conversion would blur the archive/runtime boundary, conflict with P0-045/P0-046, and imply a campaign commitment that has not been approved.

### Make selected locations playable now

Rejected. No equivalent scope removal has been named, and the one-district campaign boundary remains in force.

### Preserve only prose and images

Rejected. Prose alone cannot verify terrain coverage, landmark composition, collision, navigation, deterministic assembly, or visual readability.

## Consequences

- Legacy harbor, world, and event `.tscn` files remain archived and inactive.
- New prototype definitions live under `scripts/map/definitions/outdoor/` and share one outdoor factory and primitive vocabulary.
- Terrain additions are shared, historically plausible material classes only. Snow is excluded until a specific canonical map phase justifies it.
- Padise before/after is one definition with phase metadata rather than duplicated builders.
- Automated tests must prove full terrain coverage, stable IDs, collision and route reachability, deterministic fingerprints, and activation isolation.
- Each definition receives a deterministic visual capture at the approved gameplay scale.
