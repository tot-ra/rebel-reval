# Seamless streaming plan

Status: accepted target, flag-off. Board: **R-977** (WB-05, membership census
accepted on **R-1016**), then **R-978**..**R-980**.
ADR: [0019](adr/0019-seamless-contiguous-location-streaming.md).

This file is the operational map for ADR 0019. It does not enable runtime streaming.
`world_host/additive_residency_enabled` and `world_host/async_location_assembly_enabled`
remain **false**.

## Player-facing goal

Walk between adjacent Reval districts and harbours without a loading screen. Keep an
explicit travel beat for interiors and for every `world.*` destination.

## Membership census

Every file in `content/maps/` (29 maps) has exactly one kind. Count check: 10 streamed +
9 interiors + 10 travel = 29.

### Streamed: `world_group_id = reval_outdoor`

Physically adjacent Reval districts and harbours. R-980 builds one world-layout
manifest for this group. Current `alignment=travel` marks on some district edges do
**not** override this list. R-980 must convert those edges to reciprocal physical
seams before they can stream.

| Map id | Source | Catalog `active` | Why it streams |
|---|---|---|---|
| `lower_town_slice` | `lower_town_slice.rrmap` | true | Playable Lower Town yard and streets |
| `market_civic_quarter` | `market_civic_quarter.rrmap` | false | Central forum, adjacent to Lower Town |
| `monastery_quarter` | `monastery_quarter.rrmap` | false | Pikk/Lai precinct between civic and north wards |
| `north_quarter` | `north_quarter.rrmap` | false | Merchant ward to the Coastal Gate |
| `south_quarter` | `south_quarter.rrmap` | false | Knights District / Karja approach |
| `toompea_quarter` | `toompea_quarter.rrmap` | false | Walled Upper Town plateau |
| `archbishops_garden` | `archbishops_garden.rrmap` | false | Western Toompea plateau, same hill |
| `viru_gate_foreland` | `viru_gate_foreland.rrmap` | false | Eastern gate and Pirita approach |
| `reval_harbor_north` | `reval_harbor_north.rrmap` | false | Coastal Gate landing |
| `reval_harbor_east` | `reval_harbor_east.rrmap` | false | Kalamaja shore, adjacent landing |

Pirita and other physically contiguous outskirts stay out of this first group, as
ADR 0019 phase 7 already said.

### Interiors: explicit door transitions

ADR 0019 already kept interiors on explicit transitions. This plan keeps that rule
even for the doors the player uses most often (the forge, town hall, churches, and
tower interiors).

Reason: an interior is not a contiguous outdoor cell. Crossing one changes camera
mode, rain shelter, interior-shell lighting, and navigation volume. Putting those
packages into `reval_outdoor` would force WorldHost to own enclosed scenes before
any outdoor seam works. The frequent forge door stays a door.

| Map id | Source | Why it stays explicit |
|---|---|---|
| `kalev_smithy` | `kalev_smithy.rrmap` | Enclosed forge. Most-used door on the playable route |
| `town_hall` | `town_hall.rrmap` | Civic interior |
| `holy_spirit_church` | `holy_spirit_church.rrmap` | Church interior |
| `oleviste_church` | `oleviste_church.rrmap` | Church interior |
| `st_olafs_guild_hall` | `st_olafs_guild_hall.rrmap` | Hall interior |
| `nunnatorn_interior` | `nunnatorn_interior.rrmap` | Tower interior |
| `kuldjala_interior` | `kuldjala_interior.rrmap` | Tower interior |
| `rentenitorn_interior` | `rentenitorn_interior.rrmap` | Tower interior |
| `toompea_small_castle` | `toompea_small_castle.rrmap` | Small Castle interior compound. Unregistered benchmark source (WB-10); still assigned here so the census is complete |

### Travel: `alignment=travel`, never in the physical layout

Every `world.*` map stays a travel destination. A validator in R-980 must reject a
travel transition that is authored as a physical seam.

| Map id | Source |
|---|---|
| `world.saaremaa` | `world_saaremaa.rrmap` |
| `world.padise` | `world_padise.rrmap` |
| `world.paide` | `world_paide.rrmap` |
| `world.parnu` | `world_parnu.rrmap` |
| `world.poide` | `world_poide.rrmap` |
| `world.kanavere` | `world_kanavere.rrmap` |
| `world.sojamae` | `world_sojamae.rrmap` |
| `world.harju` | `world_harju.rrmap` |
| `world.sacred_grove` | `world_sacred_grove.rrmap` |
| `world.rebel_kings` | `world_rebel_kings.rrmap` |

## Phases 3-5

| Phase | Row | Exit gate | Flag | Rollback |
|---|---|---|---|---|
| 3 Host owns globals | R-978 / WB-06 | `--filter=test_world_host_residency`: one player, camera, environment, HUD, and navigation map across two mounted locations; global-creating packages and duplicate handles rejected; a path crosses between the two. Flag-off suite and menu-to-forge playthrough stay identical | `world_host/additive_residency_enabled=false` | Leave the flag false. Scenes keep today's ownership |
| 4 Budgeted assembly | R-979 / WB-07 (R-1005, R-1006, R-1010 close the remaining over-budget units) | `--filter=test_async_location_assembly`; staged tree equals synchronous; nav bake is byte-identical; cancel leaks nothing; per-stage timings stay inside the 4 ms frame budget on the named maps | `world_host/async_location_assembly_enabled=false` | Leave the flag false. Play stays on synchronous `MapView3D.create()` |
| 5 Seam crossing | R-980 / WB-08 | See [R-980 release criteria](#r-980-release-criteria) | Both flags above. Defaults flip **on** only after those criteria pass | `world_host/scene_swap_fallback_enabled` remains a working path |

**Phase 3 status (2026-09-27).** R-978 landed the host side, flag off:
`WorldHost.create_globals()` owns the single player, rig, camera, environment, sun, sky,
clock, HUD, session/music binding, `MapStableStateStore`, and navigation map;
`enter_location()` mounts `MapSceneBootstrap.assemble_location_package()` plus
`MapView3D.create_hosted()`; packages that create a global are rejected with
`WORLD_HOST_PACKAGE_CREATES_GLOBAL` and repeated handles with
`WORLD_HOST_DUPLICATE_STABLE_HANDLE`. One item remains before the phase 3 gate closes:
**R-1038** (scenes become launch adapters, hosted `MapViewRuntime`, input, and the
menu-to-forge playthrough in both flag states).

**R-1039 (2026-09-27).** Baked `NavigationRegion2D`s keep the flag-off
`agent_radius = 16` inset, so two real packages leave a 32 px gap at a shared
edge. `WorldHost` attaches those regions to one map and installs a deterministic
`NavigationLink2D` per active `MapWorldLayout` seam. The bake itself is
unchanged (R-979 nav parity). `--filter=test_world_host_residency`.

ADR phase 6 (NPC, quest, fauna, audio, persistence residency beyond the two-seam walk)
is follow-up work after R-980, not a fourth pack row.

## R-980 release criteria

These are the ADR 0019 acceptance gates, restated as the only conditions that may
flip the streaming flags to on. All gates apply in both directions across at least
one real district seam, then across a route with at least three seams.

### Functional continuity

- No `SceneTree.change_scene_to_packed()` on a seamless edge.
- The same player, camera, session, day/night clock, and weather instance survive.
- Player global logic position and velocity stay continuous within 0.01 logic units.
- Cross-seam keyboard movement and click navigation work after repeated load/unload.
- A stable object or dynamic entity exists at most once across owner and consumer packages.
- Saving on either side of a seam restores location, global cell/sub-cell, object deltas, and quest state.
- `alignment=travel` destinations never enter the physical layout. Every map outside
  `reval_outdoor` in this file stays on an explicit transition.

### Visual and audio continuity

- The camera never reveals missing terrain, an internal surroundings skirt, a duplicate
  wall, a lighting or sky reset, or a one-frame location flash.
- Terrain, water, roads, walls, and the transition aperture meet at the authored seam
  within the agreed geometric tolerance. After R-976, there is no vertical step.
- Location ambience and music crossfade without duplicate world-global emitters.
- Lower-detail visuals may refine after activation. No placeholder may change collision
  or interaction truth.

### Performance and residency

Use `tools/benchmarks/large_map_benchmark_config.json` unless a later measured ADR
changes the numbers:

- main-thread streaming work <= 4 ms per frame
- steady frame p95 <= 16.67 ms and p99 <= 25 ms
- resident nodes <= 7,500
- resident collision shapes <= 900
- resident static memory delta <= 280 MiB
- one 32 x 32 chunk activation <= 50 ms p95
- one overlapped navigation tile bake <= 25 ms p95
- a 30-minute seam-crossing soak returns node/RID counts to the documented cache
  baseline and shows no monotonic memory growth

An artificial delayed-I/O test must prove that low-priority visuals defer first,
authoritative unloaded space is never exposed, and the readiness miss is recorded.

The 2026-09-27 Lower Town production scene is already over the node and memory
caps (15088 nodes, 602 MiB static delta). Streaming cannot flip on until residency
is inside those caps. See the [startup baseline](reports/seamless_startup_baseline_2026-09-26.md).

## Map-activation prerequisites

This row activates no map. Only `kalev_smithy` and `lower_town_slice` are
`active=true`. The forge is an interior, so today there is **no pair of active
outdoor maps** that can demonstrate a seamless edge.

R-980 may still land the host, manifest, and tests against inactive prototypes.
A player-visible two-seam walk cannot ship until all of the following land:

1. **At least one outdoor neighbour of `lower_town_slice` is activated.** The
   activation ledger today names `market_civic_quarter` (P4-022 / P4-019),
   `north_quarter` (P4-020 / P4-023f), `south_quarter` (P4-024), and
   `toompea_quarter` (P4-025). `monastery_quarter`, `archbishops_garden`,
   `viru_gate_foreland`, `reval_harbor_north`, and `reval_harbor_east` are in
   the stream group but have no row in
   [`docs/data/location_activation_manifest.json`](data/location_activation_manifest.json)
   yet. They need a named activation owner before promotion.
2. **R-976 relief seam continuity** for every seam the demo walk crosses. WB-08
   already forbids a vertical step once that heightfield exists.
3. **R-716 / world-building visual gate** remains the promotion gate. A green
   host test does not activate a map.
4. **R-978 and R-979 exit gates**, including the remaining over-budget assembly
   units owned by R-1006 and R-1010.

## Startup baseline

Re-measured 2026-09-27. Command and tables:
[`docs/reports/seamless_startup_baseline_2026-09-26.md`](reports/seamless_startup_baseline_2026-09-26.md).
Budget streaming against those numbers, not the 2026-07-17 20 ms / 2.93 s pair.

## R-1016 census (accepted 2026-09-27)

Second-reviewer check of the three membership tables against every
`content/maps/*.rrmap` `map <id>` header:

- 29 source maps, 29 plan rows (10 streamed + 9 interiors + 10 travel)
- no map missing from the plan, no plan id absent from `content/maps/`
- no double assignment
- streamed `active` column matches the source headers (`kalev_smithy` and
  `lower_town_slice` are the only `active=true` maps; the forge stays interior)
- every table `Source` filename resolves to the same map id

Re-run:

```bash
python3 - <<'PY'
from pathlib import Path
import re
root = Path('.')
ids = [re.search(r'^map\s+(\S+)', p.read_text(), re.M).group(1)
       for p in sorted((root / 'content/maps').glob('*.rrmap'))]
plan = (root / 'docs/SEAMLESS_STREAMING_PLAN.md').read_text()
sections = {
    'streamed': re.search(r'### Streamed:.*?### Interiors:', plan, re.S).group(0),
    'interiors': re.search(r'### Interiors:.*?### Travel:', plan, re.S).group(0),
    'travel': re.search(r'### Travel:.*?## Phases', plan, re.S).group(0),
}
assigned = []
for body in sections.values():
    assigned.extend(re.findall(r'^\|\s*`([^`]+)`\s*\|', body, re.M))
assert len(ids) == 29 and ids == sorted(set(ids))
assert len(assigned) == 29 and len(assigned) == len(set(assigned))
assert set(ids) == set(assigned), set(ids) ^ set(assigned)
print('ok', len(ids))
PY
```

Accept. R-977 membership verify is closed. No interiors or travel rewrite.
