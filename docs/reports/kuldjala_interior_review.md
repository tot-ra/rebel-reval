# Kuldjala Interior Historical and Art Review

**Task:** R-250 / P4-027c
**Status:** IMPLEMENTED, HUMAN SIGN-OFF PENDING
**Runtime state:** developer-only (`active=false`)

## Decision boundary

The package implements a dedicated Kuldjala / Golden Leg Tower interior without reusing Nunnatorn's open-backed rectangular plan or named encounter. The source dossier records Kuldjala as the circa-1310 Golden Leg tower at the north-west circuit and describes an approximately 9 m wide, 7 m high horseshoe form. It also supports wooden upper fighting decks and wall-walk use as the conservative early-fourteenth-century defensive pattern.

The repository does not establish an excavated room plan, stair position, named occupant, or 1343 encounter. Those details remain explicitly reconstructed or invented gameplay authorship.

## Authored floor plan

| Band | Treatment | Confidence |
| --- | --- | --- |
| Ground chamber | Stone-floored repair/store chamber inside the closed western arc | plausible composite |
| Upper fighting chamber | Timber-floored chamber reached by one internal stair | plausible composite |
| East opening | City-facing opening between short masonry returns, preserving the horseshoe reading | plausible composite |
| Wall-walk | Timber deck adjoining the east opening; counted as the third traversal band, not an invented masonry storey | plausible composite |
| Stair and hatch positions | Aligned route selected for readable gameplay and collision clearance | invented reconstruction |

The RRMap uses a closed west side, north and south arcs, and diagonal short returns toward the east opening. It avoids a full rectangular enclosure and avoids adding a third enclosed floor. The shared tower contract's `kuldjala_floor_roof` stable ID names the open fighting deck for compatibility; the authored comments and anchors prevent it from being interpreted as another chamber.

## Encounter boundary

The Golden Leg Warden, the illicit repair ledger, and the crossbow wall-walk guard are invented. The package deliberately differs from Nunnatorn:

- the named boss uses the watchman archetype rather than a sergeant;
- the escort occupies the wall-walk and uses the crossbowman archetype;
- the non-lethal branch exposes a repair ledger and forces a stand-down;
- the reward and evidence anchors remain separate one-shot records.

## Automated evidence

The scoped acceptance suite verifies:

- parse and canonical RRMap stability;
- route reachability from entry to both enclosed levels and the wall-walk;
- horseshoe boundary/opening markers;
- reciprocal exterior/interior door IDs;
- distinct kill and bypass outcomes;
- immutable outcome, one-shot rewards, save/load persistence, and retry restoration;
- developer-only catalog and completed-tower package wiring.

## Required human review

Historical and art reviewers must inspect the floor-plan silhouette and gameplay capture before changing this report to signed. Until then, Kuldjala remains developer-only and the task must not claim release activation.

## Sources

1. [`history/dossiers/topography/walls-gates-towers.md`](../../history/dossiers/topography/walls-gates-towers.md), Golden Leg registry row and early-fourteenth-century tower-form summary.
2. [`docs/reports/reval_fortifications_1343.md`](reval_fortifications_1343.md), dated fortification registry boundary.
3. [`content/maps/kuldjala_interior.rrmap`](../../content/maps/kuldjala_interior.rrmap), authored implementation.
