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

## R-785 presentation evidence packet

The reproducible presentation packet is now captured from the production `MapView3D` with the same
camera contract for every plate: `1280x720`, orthographic gameplay scale `33.75`, pitch `-30`,
yaw `45`, and camera distance `90`. The day/night pairs share a framing key; only the lighting
state changes. The packet includes the interior route, an exterior tower approach, and a closer
exterior view of the south door and return spawn.

| View | Day plate | Night plate | Stable-ID coverage | Packet result |
| --- | --- | --- | --- | --- |
| Interior three-band route and wall-walk | [`rentenitorn_interior_day.png`](images/rentenitorn/rentenitorn_interior_day.png) | [`rentenitorn_interior_night.png`](images/rentenitorn/rentenitorn_interior_night.png) | `rentenitorn_interior_entry`, `rentenitorn_floor_ground`, `rentenitorn_floor_watch`, `rentenitorn_floor_roof`, `rentenitorn_wall_walk` | **PASS - matched 1280x720 pair** |
| Exterior tower approach | [`north_quarter_merchant_wall_tower_northwest_day.png`](images/rentenitorn/north_quarter_merchant_wall_tower_northwest_day.png) | [`north_quarter_merchant_wall_tower_northwest_night.png`](images/rentenitorn/north_quarter_merchant_wall_tower_northwest_night.png) | `merchant_wall_tower_northwest` | **PASS - matched 1280x720 pair** |
| Exterior south door and return spawn | [`north_quarter_merchant_wall_tower_northwest_door_day.png`](images/rentenitorn/north_quarter_merchant_wall_tower_northwest_door_day.png) | [`north_quarter_merchant_wall_tower_northwest_door_night.png`](images/rentenitorn/north_quarter_merchant_wall_tower_northwest_door_night.png) | `merchant_wall_tower_northwest`, `rentenitorn_enter`, `merchant_wall_tower_northwest_return` | **PASS - matched 1280x720 pair** |

The machine-readable metadata is [`capture_manifest.json`](images/rentenitorn/capture_manifest.json).
It records both map fingerprints, the `active=false` boundary for the interior and exterior maps,
the OpenGL compatibility renderer, stable IDs, focus coordinates, camera settings, and the three
matched day/night framing keys. The capture runner is
[`tools/capture_rentenitorn_presentation.gd`](../../tools/capture_rentenitorn_presentation.gd),
and its packet contract is [`test_rentenitorn_presentation.gd`](../../tests/godot/test_rentenitorn_presentation.gd).

## Review observations (not human approval)

The source-bound historical review confirms the conservative interpretation supported by the
current dossier: only the tower's pre-mid-fourteenth-century presence is attested. The closed
rectangular shell, three traversal bands, timber deck, stairs, and room uses remain labelled as
plausible or invented reconstruction. The authored shell is distinct from Nunnatorn's open-backed
bartizan treatment, and no later tower silhouette is introduced. This is an agent/source review,
not a named human historical sign-off.

The packet is suitable for an art reviewer to inspect the three traversal bands, the wall-walk,
and the south exterior door at gameplay distance in matched day/night lighting. The capture
contract confirms framing and output integrity, but it cannot certify visual readability or replace
an art review. No map/catalog/transition activation was changed; Rentenitorn remains developer-only.

## Reproduction and verification

```text
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_rentenitorn_presentation.gd
# PASS: 6 PNG plates written at 1280x720; shutdown emitted known resource-leak diagnostics

GODOT_LOG_DIR=/tmp/r785-test-rentenitorn-presentation \
  ./tools/run_godot_checked.sh --require-test-summary r785-rentenitorn-presentation -- \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_rentenitorn_presentation
# PASS: 1 file, 2 tests, 0 failures, 0 errors

python3 -m gdtoolkit.linter \
  tools/capture_rentenitorn_presentation.gd tests/godot/test_rentenitorn_presentation.gd
# PASS: no problems found
```

## Required human review

The automated packet and source review are complete, but the report does not invent human approval.
A named historical reviewer and a named art reviewer must inspect the six linked plates and record
observations below before this report changes to signed. Until then Rentenitorn stays developer-only
and the task remains in review.

| Role | Reviewer | Date | Observation | Verdict |
| --- | --- | --- | --- | --- |
| Historical reviewer | **Not assigned** | - | Confirm that a closed rectangular minimum-claim plan is defensible for a tower attested only as present before the mid-14th c.; confirm it is neither the Nunnatorn open-backed bartizan nor a later silhouette. | **BLOCKED** |
| Art reviewer | **Not assigned** | - | Confirm that all three traversal bands, the wall-walk door, and the exterior south door read at gameplay distance in both matched lighting states; record any concrete amendment and owner. | **BLOCKED** |

Do not change either row to PASS based on the automated tests or this agent/source review. The
portfolio acceptance remains with P4-027f / R-261 and this task does not activate the map.

## Sources

1. [`history/dossiers/topography/walls-gates-towers.md`](../../history/dossiers/topography/walls-gates-towers.md), Rent Tower registry row and early-fourteenth-century tower-form summary.
2. [`docs/reports/reval_fortifications_1343.md`](reval_fortifications_1343.md), dated fortification registry boundary.
3. [`content/maps/rentenitorn_interior.rrmap`](../../content/maps/rentenitorn_interior.rrmap), authored implementation.
