---
status: accepted
review_type: historical-art-boundary
owner: R-622
parent: R-251
depends_on: R-621
snapshot: Spring 1343
---

# Nunnatorn historical and art review

## Review decision

**Status: accepted with bounded reconstruction.** This record accepts the historical and
art direction needed to author the Nunnatorn package. It does not claim that a measured
1343 interior survey survives, and it does not activate a map or approve runtime content.
The downstream implementation must preserve the distinction between attested tower
identity and reconstructed interior gameplay space.

The accepted read is an **early-14th-century, open-backed tower facing the city or
monastery yard**, using the documented rectangular/bartizan type as its exterior massing.
The open-backed side is a restrained gameplay reconstruction: the evidence supports the
tower's period presence and broad form, but not every internal partition, stair, or
furnishing. The city-facing side must remain visually open and must not be filled into the
later horseshoe enclosure.

## Evidence ledger

| Review subject | Confidence | Accepted production consequence |
|---|---|---|
| Nunnatorn / Nun's Tower present in the first half of the 14th century | **attested** | Retain the exterior identity `monastery_wall_tower_northwest` on `monastery_quarter`. |
| Rectangular or bartizan early tower type | **attested type** | Use a compact limestone tower with a modest wooden upper fighting deck; do not borrow later monumental silhouettes. |
| Open-backed city-facing arrangement | **plausible composite / bounded reconstruction** | Leave the city-yard side readable as open-backed; use only the minimum walls and supports needed for navigation and combat. |
| Three-level interior route | **gameplay reconstruction** | Author ground, watch/middle, and roof/open-deck levels because they are the frozen R-621 route contract, not because three floors are archaeologically proven. |
| Stair or ladder connection | **unknown, reconstructed for reachability** | Choose one legible vertical route and label its exact placement as implementation detail. |
| Upper connection to the curtain wall-walk | **plausible composite, pending runtime verification** | Connect `nunnatorn_floor_roof` to `nunnatorn_wall_walk` and the existing curtain walk without adding a later defensive circuit. |
| Boss, alternate resolution, loot, and evidence | **invented gameplay content** | Keep these as authored systems and never present them as archival occupants, relics, or documented finds. |

## Accepted floor-plan boundary

The review accepts the following minimum route, matching the stable IDs in
[`nunnatorn_interior_contract.md`](nunnatorn_interior_contract.md):

1. **Ground floor, `nunnatorn_floor_ground`:** inward-facing arrival from
   `nunnatorn_enter`, a compact service or storage area, and a clear combat approach.
2. **Watch or middle floor, `nunnatorn_floor_watch`:** a small working/watch level
   reached by the vertical route. Its partitions and furnishing remain reconstructed.
3. **Upper roof level, `nunnatorn_floor_roof`:** a defensive level below the open
   fighting deck, with a readable route to `nunnatorn_wall_walk`.
4. **Wall-walk route, `nunnatorn_wall_walk`:** an upper-level exit to the existing
   curtain wall-walk, arriving at `nunnatorn_wall_walk_entry`. This is a route
   relationship, not evidence for a specific surviving stair or hatch.

The gameplay-only package IDs remain explicitly authored and non-historical: `nunnatorn_boss`,
`nunnatorn_boss_defeated`, and `nunnatorn_boss_alternate_resolution` for encounter
outcomes; `nunnatorn_loot` and `nunnatorn_evidence` for separate reward/evidence
records; and `nunnatorn_state` plus `nunnatorn_retry` for persistence and re-entry.
Their presence in the contract does not imply an attested resident, relic, document, or
historical event.

The interior must return through `nunnatorn_exit` to
`monastery_wall_tower_northwest_return`. Exact dimensions, room partitions, stair
geometry, props, lighting, and audio remain implementation choices for R-623 and R-628,
subject to the exclusions below and the R-270 shared tower contract.

## Historical and art exclusions

The following forms are rejected for the Spring 1343 Nunnatorn package:

- the **later horseshoe rebuild** as the tower's 1343 interior or primary silhouette;
- any **post-1343 tower fabric**, completed later defensive circuit, or later tower
  additions presented as contemporary;
- a sealed horseshoe enclosure created by filler walls, decorative infill, or a copied
  later courtyard arrangement;
- a mature barbican, foregate, zwinger, or later gate complex;
- cannon embrasures, firearm ports, or a 15th-century raised curtain profile;
- the later NW tower cluster, including Loewenschede, Epping, Ropemakers', Bath,
  Nunnadetagune, or other third-quarter-14th-century additions;
- Fat Margaret, Kiek in de Kök, or any 15th/16th-century tourist or cannon-tower
  silhouette;
- a finished dungeon or fixed garrison roster at a construction-candidate position;
- a named historical boss, archival loot cache, or excavated evidence claim without a
  separate source and canon decision.

Wooden fighting platforms, simple hoardings, restrained limestone, repair patches, and
period-appropriate service dressing are allowed as **plausible composite** art direction.
They must remain subordinate to the early tower mass and must not close the open-backed
side.

## Review boundary and downstream handoff

This report accepts the authoring brief, not the final implementation. R-623 may author
the dedicated interior map using the three stable floor IDs and the wall-walk relation.
R-624 owns reciprocal transition wiring, R-625 owns the named encounter and outcomes,
R-626 owns loot/evidence, R-627 owns persistence/retry, R-628 owns lighting/audio
readability, and R-629 owns independent package verification. None of those tasks may
silently promote a reconstructed detail to an attested historical fact.

Human visual approval remains a separate downstream check: the final capture must show an
open-backed early tower at gameplay scale, distinguish it from later horseshoe forms, and
prove that no rejected silhouette leaked into the package. Automated traversal or save
tests cannot substitute for that visual/historical review.

## Sources

1. [`history/dossiers/topography/walls-gates-towers.md`](../../history/dossiers/topography/walls-gates-towers.md), especially the 1343 tower verdict, early tower forms, wall-walk context, and post-1343 exclusions.
2. [`docs/reports/reval_fortifications_1343.md`](reval_fortifications_1343.md), especially the conservative completed-tower baseline, construction-state policy, mini-dungeon boundary, and explicit exclusions.
3. [`docs/reports/nunnatorn_interior_contract.md`](nunnatorn_interior_contract.md), the dependency contract for stable IDs, floors, wall-walk, transitions, and review ownership.
4. [`scripts/map/reval_fortification_registry.gd`](../../scripts/map/reval_fortification_registry.gd), the runtime-facing historical registry entry for Nunnatorn's dated exterior identity.
5. [Medieval Heritage, Tallinn city defensive walls](https://medievalheritage.eu/en/main-page/heritage/estonia/tallinn-city-defensive-walls/), the external synthesis used by the project dossier for the first-quarter and mid-14th-century reconstructions.
6. [Gatehouse of the Viru Gate](https://en.wikipedia.org/wiki/Gatehouse_of_the_Viru_Gate), retained in the project dossier as a supplementary chronology reference for separating 1343 fabric from later gatehouse forms.

## Verification notes

- The accepted decision names the open-backed early-14th-century form.
- The review records the three implementation floors and the wall-walk relationship.
- The exclusion checklist names the later horseshoe rebuild, post-1343 fabric, later tower
  additions, barbicans, firearms, later skyline towers, and unsupported archival claims.
- Local source files and external URLs were checked for existence while preparing this
  record.
- No runtime files, map activation records, or review images were changed.
- The R-621 contract remains unchanged and consistent with this review.
