# Rentenitorn Interior Historical and Art Review

**Task:** R-246 / P4-027d
**Status:** IMPLEMENTED, HUMAN SIGN-OFF PENDING
**Runtime state:** developer-only (`active=false`)

## Evidence boundary

The dossier records exactly one fact about the Rent Tower (*Rentenitorn*): it stood on the
north-west circuit **before the mid fourteenth century** and is therefore present in the
April 1343 snapshot. Unlike Nunnatorn (bartizan form, first half of the fourteenth century)
and Kuldjala (horseshoe, circa 1310 core), the sources reviewed here give **no plan, no
height, no wall thickness, no room count, and no named occupant** for this tower.

That gap is the design constraint, not an invitation to fill. The interior is authored as a
deliberate **minimum-claim reconstruction**: every element below is either the shared tower
contract, a general early-fourteenth-century form recorded in the dossier, or explicitly
labelled invention that can be replaced without renaming a single stable ID.

## Authored floor plan

| Band | Treatment | Confidence |
| --- | --- | --- |
| Shell | Compact closed rectangular curtain tower | plausible composite |
| South door | Single inward, city-facing door on the registry `door_side` | registry-constrained |
| Ground strongroom | Stone-floored dues/strongroom chamber | invented reconstruction |
| Counting chamber | Timber-floored rent chamber, the middle traversal band | invented reconstruction |
| Fighting deck | Timber upper deck at door level, joining the wall-walk | plausible composite |
| Wall-walk | Timber deck west of the shell, reached by one authored door | plausible composite |
| Stair and partition openings | Alternating corners for readable gameplay and collision clearance | invented reconstruction |

The tower is authored **closed** rather than open-backed. The dossier's early-fourteenth-century
form list allows rectangular, semicircular, and horseshoe towers on this circuit, and a closed
plan is the conservative reading for a work named for the town's rents: it can hold a lockable
strongroom. It also keeps the package visually distinct from the two shipped north-west towers
instead of restating Nunnatorn's open-backed rectangle at a different position.

The shared tower contract names the third traversal band `rentenitorn_floor_roof`. Here it is
the timber fighting deck at door level, not an invented third masonry storey; the RRMap comments
carry that qualification so tooling cannot promote it into a claimed chamber.

## Reversibility

Every uncertain element is reversible because none of it is load-bearing for identity:

- the stable IDs come from `CompletedTowerPackages`, so re-plotting the interior does not
  invalidate saves, transitions, or the portfolio ledger;
- the exterior tower keeps its registry footprint, `tower=true`, and `door_side=south`, so a
  revised interior plan never moves the curtain or reopens sealed wall collision;
- `content/examples/valid/encounter.rentenitorn_boss.json` is `confidence: invented`,
  `canon_status: draft`, `approval.status: draft`;
- the map stays `active=false` and developer-only until this report is signed.

## Encounter boundary

The Rent Tower Watcher, the farmed dues, and the sealed-tally stand-down are invented. The
package deliberately differs from both shipped towers:

- the named boss uses the crossbowman archetype, inverting the usual leader/escort pairing;
- the escort is a hired strongarm on the strongroom floor, not a tower guard beside the boss;
- the non-lethal branch serves the town's sealed rent tally and forces the strongroom open;
- the strongroom is its own durable state and can only unseal after the watcher is resolved.

## Automated evidence

The scoped acceptance suite verifies:

- parse and canonical RRMap stability;
- route reachability from the entry to all three traversal bands and the wall-walk;
- the closed-shell wall set and both authored doors;
- reciprocal exterior/interior transition IDs through the shared contract validator;
- distinct kill and bypass outcomes with a boss identity that does not clone Nunnatorn;
- immutable outcome, one-shot rewards, sealed-strongroom rules, save/load persistence, and
  retry restoration without scene nodes in the payload;
- developer-only catalog, blueprint-registry, and completed-tower package wiring;
- the reversibility markers above, asserted from the content package and this report.

## Required human review

Historical and art reviewers must inspect the floor-plan silhouette and a gameplay capture
before this report changes to signed. Until then Rentenitorn stays developer-only and the task
must not claim release activation.

## Sources

1. [`history/dossiers/topography/walls-gates-towers.md`](../../history/dossiers/topography/walls-gates-towers.md), Rent Tower registry row and early-fourteenth-century tower-form summary.
2. [`docs/reports/reval_fortifications_1343.md`](reval_fortifications_1343.md), dated fortification registry boundary.
3. [`content/maps/rentenitorn_interior.rrmap`](../../content/maps/rentenitorn_interior.rrmap), authored implementation.
