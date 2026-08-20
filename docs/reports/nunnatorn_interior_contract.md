---
status: contract-frozen
owner: R-621
parent: R-251
depends_on: R-270
snapshot: Spring 1343
---

# Nunnatorn interior contract

This document freezes the implementation boundary for the Nunnatorn / Nun's Tower
interior package. It is an authoring contract, not a runtime implementation, a map
activation decision, or a claim that the surviving evidence gives a day-exact floor
plan.

## 1. Historical and art decision

Nunnatorn is treated as a **present early-14th-century tower in an open-backed,
city-facing form**, derived from the documented rectangular/bartizan type. The
open-backed arrangement is a **bounded reconstruction** for gameplay and must be
reviewed as such. The source evidence supports the tower's presence and early form,
but does not prove every interior partition, stair run, or furnishing.

The package must not depict:

- the later horseshoe rebuild as Nunnatorn's 1343 interior;
- post-1343 tower fabric or a later completed defensive circuit;
- a mature barbican, foregate, cannon embrasure, or sixteenth-century wall profile;
- an invented archival certainty for the room plan, garrison, boss identity, or loot.

The historical/art review boundary is explicit: a canon reviewer signs the dated form,
open-backed interpretation, and exclusions; an art reviewer signs silhouette, material,
readability, and non-anachronistic dressing. Neither review is implied by this
contract, and neither may be replaced by a passing runtime test.

## 2. Stable package IDs

All IDs below are reserved for the future package. R-621 owns this contract. Runtime
wiring belongs to the owner task named in the table, after the shared R-270 contract is
done. Names are stable even if the scene file or generated geometry changes.

| Concern | Stable ID | Contract meaning | Owner |
|---|---|---|---|
| Exterior map | `monastery_quarter` | Existing exterior map that owns the tower door | R-270 / R-624 |
| Interior map | `nunnatorn_interior` | Dedicated enterable tower map | R-623 |
| Interior scene | `nunnatorn_interior_scene` | Packed scene identity for the interior | R-623 |
| Exterior tower | `monastery_wall_tower_northwest` | Existing Nunnatorn building identity | R-270 / R-623 |
| Exterior door | `nunnatorn_exterior_door` | Inward-facing ground-level entrance on the exterior tower | R-624 |
| Interior arrival | `nunnatorn_interior_entry` | Safe arrival cell immediately inside the door | R-624 |
| Exterior return spawn | `monastery_wall_tower_northwest_return` | Safe exterior arrival after leaving the interior | R-624 |
| Exterior -> interior transition | `nunnatorn_enter` | Reciprocal door transition into the tower | R-624 |
| Interior -> exterior transition | `nunnatorn_exit` | Reciprocal return transition to the tower door | R-624 |
| Ground floor | `nunnatorn_floor_ground` | Entry, service/storage space, and combat approach | R-623 |
| Middle floor | `nunnatorn_floor_watch` | Compact watch/working level connected to the stair | R-623 |
| Upper floor | `nunnatorn_floor_roof` | Upper defensive level below the open fighting deck | R-623 |
| Wall-walk route | `nunnatorn_wall_walk` | Reachable exit from the upper level to the curtain wall-walk | R-623 |
| Wall-walk arrival | `nunnatorn_wall_walk_entry` | Safe arrival anchor on the existing curtain walk | R-623 |
| Boss encounter | `nunnatorn_boss` | Named encounter slot; identity remains authored later | R-625 |
| Lethal outcome | `nunnatorn_boss_defeated` | Boss defeated state and outcome event | R-625 |
| Alternate outcome | `nunnatorn_boss_alternate_resolution` | Non-lethal or negotiated authored resolution | R-625 |
| Loot bundle | `nunnatorn_loot` | Tower-specific reward container, not a historical claim | R-626 |
| Evidence bundle | `nunnatorn_evidence` | Evidence/relic/document bundle tied to the encounter | R-626 |
| Persistence key | `nunnatorn_state` | Saved package state including door, boss, and loot flags | R-627 |
| Retry state | `nunnatorn_retry` | Re-entry/retry contract after either boss outcome | R-627 |
| Lighting/audio packet | `nunnatorn_readability` | Lighting, ambience, and readability review surface | R-628 |
| Acceptance packet | `nunnatorn_acceptance` | Independent verification record for the complete package | R-629 |

## 3. Geometry and route contract

The package must preserve the exterior building ID and connect to the existing inward-
facing tower door. The interior is a compact vertical route, not a new monastery map:

1. `nunnatorn_interior_entry` arrives on `nunnatorn_floor_ground` without trapping the
   player in geometry or combat.
2. `nunnatorn_floor_ground`, `nunnatorn_floor_watch`, and `nunnatorn_floor_roof` are
   all authored and reachable in both directions through a stair or ladder route.
3. `nunnatorn_wall_walk` is reachable from the upper level and returns to a safe
   `nunnatorn_wall_walk_entry` on the existing curtain wall-walk.
4. `nunnatorn_exit` returns to
   `monastery_wall_tower_northwest_return`; entering and leaving repeatedly must not
   duplicate the player, strand the camera, or bypass collision.
5. The open-backed side reads toward the city/interior yard. It must not be sealed into
   a later horseshoe enclosure by filler walls or decorative geometry.

Exact dimensions, stair placement, partitions, dressing, and sightline treatment are
implementation choices subject to the historical/art review boundary. The route must
remain legible at gameplay scale and preserve navigation, collision, camera, and
transition budgets from R-270.

## 4. Acceptance-to-owner matrix

| R-251 acceptance clause | Required contract evidence | Stable IDs | Owner task |
|---|---|---|---|
| Dedicated Nunnatorn package | Separate interior map and packed scene; no map activation | `nunnatorn_interior`, `nunnatorn_interior_scene` | R-623 |
| Open-backed early-14th-century form | Dated art brief and review notes; later horseshoe form explicitly rejected | `monastery_wall_tower_northwest` | R-621, R-622, R-628 |
| Reciprocal exterior/interior door | Both directions, safe arrival anchors, no duplicate/spoofed route | `nunnatorn_enter`, `nunnatorn_exit`, `nunnatorn_interior_entry`, `monastery_wall_tower_northwest_return` | R-624 |
| All floors reachable | Ground, watch/middle, and upper/roof levels with vertical route | `nunnatorn_floor_ground`, `nunnatorn_floor_watch`, `nunnatorn_floor_roof` | R-623 |
| Wall-walk navigation | Upper level reaches the curtain wall-walk and its safe anchor | `nunnatorn_wall_walk`, `nunnatorn_wall_walk_entry` | R-623 |
| Named boss | Authored encounter with tested combat boundary | `nunnatorn_boss`, `nunnatorn_boss_defeated` | R-625 |
| Alternate resolution | Authored non-lethal/negotiated result with distinct state | `nunnatorn_boss_alternate_resolution` | R-625 |
| Loot and evidence | Reward and evidence records remain separate and authored | `nunnatorn_loot`, `nunnatorn_evidence` | R-626 |
| Persistence and retry | Save/load preserves door, boss, loot/evidence, and re-entry outcome | `nunnatorn_state`, `nunnatorn_retry` | R-627 |
| Lighting and audio | Readability packet supports the open-backed silhouette and route | `nunnatorn_readability` | R-628 |
| Full verification | Traversal, collision, camera, transitions, outcomes, save/retry, and packaged checks | `nunnatorn_acceptance` | R-629 |

The shared enterable-tower semantics, including common transition and persistence
expectations, remain owned by R-270. This document adds Nunnatorn-specific IDs and
historical boundaries; it does not duplicate or supersede that shared contract.

## 5. Evidence and review ledger

| Topic | Status | Permitted implementation use |
|---|---|---|
| Nunnatorn present by the first half of the 14th century | Attested type / bounded historical baseline | Use the early tower identity and dated exterior form |
| Rectangular/bartizan tower form | Attested in the project research baseline | Use as the silhouette and starting massing |
| Open-backed interior arrangement | Bounded reconstruction | Use only with explicit canon/art review; do not cite as excavated fact |
| Exact floor count and room partitions | Unknown | Choose the minimum route needed by R-251 and label it reconstructed |
| Exact stair/ladder and wall-walk connection | Unknown | Reconstruct for reachability under R-270, pending review |
| Named boss, alternate resolution, loot, evidence | Game-authored | Must be canon-consistent and clearly not presented as archival fact |
| Later horseshoe rebuild and post-1343 fabric | Forbidden for this package | Reject during art/history review and acceptance checks |

## 6. Verification contract

Before R-621 can be closed, the report smoke check must find the following semantic
anchors: `open-backed`, `early-14th-century`, `horseshoe`, `post-1343`, every reserved
ID in the stable-ID table, both reciprocal transition IDs, all three floor IDs,
`nunnatorn_wall_walk`, boss outcomes, loot/evidence, persistence/retry, and the source
links below. Markdown must also pass:

```bash
git diff --check -- docs/reports/nunnatorn_interior_contract.md
```

This is a source contract only. It does not claim that R-251 is implemented or that
R-270 is complete.

## Sources

1. [`history/dossiers/topography/walls-gates-towers.md`](../../history/dossiers/topography/walls-gates-towers.md) - Nunnatorn presence, early rectangular/bartizan form, 1343 exclusions, wall-walk context, and source list.
2. [`docs/reports/reval_fortifications_1343.md`](reval_fortifications_1343.md) - conservative 1343 tower baseline, stable exterior ID, inward-facing door, mini-dungeon acceptance boundary, and post-1343 exclusions.
3. [`R-270`](../../TODO.md) - shared enterable-tower contract dependency. The board task is authoritative if the legacy TODO index differs.
4. [`R-251`](../../TODO.md) - parent Nunnatorn package acceptance clauses. The board task is authoritative if the legacy TODO index differs.
