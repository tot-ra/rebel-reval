# R-455 - City elevation and ditch readability

## Scope

Acceptance coverage for terrain elevation/grades, player-eye and top-down readability, recessed ditch/water visibility, terrain/object alignment, shoreline continuity, patrol routes, and camera bounds. This report deliberately separates measurable runtime evidence from visual evidence that is not exposed by the current public API.

## Evidence

| Area | Result | Evidence |
| --- | --- | --- |
| Toompea base elevation | PASS | ; guarded by . |
| Deterministic terrain height | PASS | The acceptance test calls  twice for the same cell and compares the result. |
| Elevation grades/profiles | BLOCKED |  exists in the contract but is empty for the target fixtures. No authored grade profile can be accepted from that data. |
| Monastery ditch/water presence | PASS | Built terrain contains water cells. |
| Harbor shoreline continuity | PASS | Harbor North contains water cells with non-water neighboring cells; this guards against an isolated or disconnected water region. |
| Recessed ditch/water readability | BLOCKED | Authored/runtime evidence indicates a recessed water surface, but there is no public ditch-depth semantic that this acceptance test can assert. A rendered mesh/camera capture is still required for visual acceptance. |
| Terrain/object alignment | BLOCKED | Building and terrain contracts are guarded, but exact rendered footprint alignment is not observable from the current public test API. |
| Player-eye/top-down readability | BLOCKED | Requires a Metal rendered capture with validated PNG dimensions; no screenshot is claimed by this data-only test. |
| Patrol routes | PASS | Toompea and Lower Town must expose non-empty patrol arrays with at least one two-point segment. |
| Camera bounds | PASS | Toompea and Lower Town camera bounds must be non-empty  values. |

## Verification

Run the focused GUT test with:



Known unrelated baseline failures remain out of scope: monastery composition/empty-region checks, an extra transition marker, Karja Gate, and  expecting removed .

## Decision

R-455 is **partially accepted** for measurable elevation, water/shore adjacency, patrol, and camera contracts. It remains **blocked** for authored grade profiles, rendered player-eye/top-down readability, mesh-proven ditch depth, and exact rendered object alignment.
