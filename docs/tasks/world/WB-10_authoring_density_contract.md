# WB-10: A machine-checkable density and variety contract for exterior maps

Board row: **R-982**. Priority: high. Depends on: none.

## Player-facing goal

None directly. This row turns "the districts feel like generic boxes" from an opinion into a number
that fails a build, so R-985 and R-986 have a target and cannot drift back.

## Why this is needed

The measured baseline, counted from `content/maps/*.rrmap`:

| Map | Cells | Props | Props / 1000 cells | Decals | Styles |
|---|---|---|---|---|---|
| `kalev_smithy` (interior, shipped) | 364 | 41 | **112.6** | 7 | 3 |
| `lower_town_slice` (active district) | 19456 | **39** | **2.0** | 11 | 63 |
| `south_quarter` | 32256 | 15 | 0.5 | 0 | 7 |
| `toompea_quarter` | 27648 | **9** | **0.3** | 0 | 14 |

Toompea carries nine props over about 21 000 m². The shipped forge interior is fifty-six times
denser than the one active outdoor district. Twenty-six of twenty-nine maps have zero decals.

There is already a fail-closed acceptance gate for exterior maps -
`docs/WORLD_BUILDING_VISUAL_GATE.md` with `tools/verify_world_building_visual_gate.py` - but its
rubric rows are human judgements ("repetition", "historical coherence") and its automated side does
not measure density, variety or landscape bedding at all. So nothing stops a map shipping empty.

## Deliverable

1. **Authoring thresholds** added to `docs/data/map_composition_thresholds.json` per map class -
   dense urban, sparse urban, foreland, rural, interior - covering at minimum:
   - props per 1000 walkable cells, with a floor derived from the interior benchmark rather than
     from the current outdoor maps, which are the thing being fixed;
   - decals per 1000 walkable cells;
   - distinct prop kinds, so density cannot be met by cloning one barrel;
   - the largest share any single prop kind or style may take;
   - wealth-tier and age-tier spread once R-981 lands, ignored before that;
   - relief span, reusing the R-951 `elevation_range_min` mechanism;
   - vegetation and ground-cover share on unbuilt land;
   - a maximum run of identical adjacent building **footprints**, which is the authoring-side
     "row of boxes" failure. Building *appearance* repetition is **AR-13's** metric, not this
     row's - see the boundary note below.
2. **`MapCompositionAudit` measures them** and reports per map, with each new check as a stable
   diagnostic code.
3. **`tools/verify_map_composition.py` enforces them** for maps at `scope=production`, and reports
   without failing for `scope=prototype`, so the inactive districts show their gap without blocking
   CI today.
4. **The gate is wired in.** `tools/verify_world_building_visual_gate.py` consumes the composition
   result as an automated row, so a map cannot be marked promotable while it fails density.
5. **A published baseline table** for all 29 maps, so R-986 and every later map pass can be scored
   against a fixed starting point.

## Allowed files

`docs/data/map_composition_thresholds.json`, `scripts/map/map_composition_audit.gd` and its `.uid`,
`tools/audit_map_composition.gd` and its `.uid`, `tools/verify_map_composition.py`,
`tools/verify_world_building_visual_gate.py`, `docs/data/world_building_visual_benchmark.json`,
`tests/python/test_verify_map_composition.py`,
`tests/godot/test_map_composition_density.gd` and its `.uid`,
`docs/WORLD_BUILDING_VISUAL_GATE.md`, `docs/MAP_AUTHORING.md`,
`docs/reports/map_density_baseline_2026-09-26.md`,
`docs/tasks/world/WB-10_authoring_density_contract.md`, `TODO.md`.

## Boundary against AR-13 (architecture pack)

The architecture pack's **AR-13** (`docs/tasks/architecture/AR-13_repetition_audit_gate.md`, board
row R-971) owns building **appearance** repetition: per-map distinct-silhouette count,
nearest-neighbour identical-appearance distance, part-reuse histogram, and the
`landmark_architecture` and repetition rows of the visual gate.

This row owns **dressing and ground**: props, decals, distinct prop kinds, vegetation and
ground-cover share, relief span, and the identical-adjacent-*footprint* run. A building can pass
AR-13 with a beautiful varied silhouette and still stand in an empty street; it is this row that
catches that.

Both rows write to `tools/verify_world_building_visual_gate.py` and
`docs/data/world_building_visual_benchmark.json`. Whichever lands second must extend the other's
rows rather than replace them, and must not duplicate a metric the first already defines. If both
are in flight at once, coordinate before touching the shared manifest.

## Constraints and non-goals

Do not change any map in this row. Do not add a building-appearance or silhouette metric - that is
AR-13. Do not promote or activate any map. Do not make the new
thresholds fail CI for maps that are already `scope=production` until R-986 has raised them -
land the thresholds, publish the gap, and let R-986 close it. State that grace explicitly in the
threshold file rather than setting the floors low enough to pass.

## Verification

- `python3 tools/verify_map_composition.py` over all 29 maps, producing the baseline table.
- `python3 -m unittest tests.python.test_verify_map_composition -v`
- `godot --headless --path . --script tools/run_godot_tests.gd` with
  `test_map_composition_density.gd` asserting each new metric on a fixture with a known answer,
  including the identical-footprint-run detector and the single-kind-share cap.
- `python3 tools/verify_world_building_visual_gate.py` still returns `BLOCKED` for the right
  reasons, now including density, and its JSON names the failing metric per map.
- `python3 tools/verify_map_audit.py`, `generate_active_docs_report.py --check`
- A second reviewer confirms each floor is justified against the interior benchmark or a cited
  reference, and is not reverse-engineered from the current outdoor maps.

## Doc updates

`docs/WORLD_BUILDING_VISUAL_GATE.md` documents the new automated rows.
`docs/MAP_AUTHORING.md` states the density contract an author must meet before requesting promotion.

## Decisions (implementation, 2026-09-26)

- **Walkable cells** are non-water cells outside counted building footprints, the same denominator
  as the P1-036 `surface_shares`. The benchmark therefore reads 143.4 props / 1000 walkable cells
  for `kalev_smithy` (41 over 286), not the 112.6 per total cell quoted above.
- **Trees and bushes are not dressing.** They count toward `ground_cover_pct`, so the prop floor
  cannot be met by planting trees.
- **Floors are benchmark x class fraction**: interior 0.5, dense urban 0.25, sparse urban 0.125,
  foreland and rural 0.0625. The two factors behind each fraction are written into
  `density_contract.derivation`. Ground-cover floors are the lowest P0-072 dossier grass band for
  that class; relief reuses the 0.3 m `elevation_range_min`; the footprint-run cap of 3 follows
  the three R-003 house tiers.
- **Grace:** only `kalev_smithy` and `lower_town_slice` compile as `scope=production`. The smithy
  passes; `lower_town_slice` has a `production_grace` entry until R-986, which must delete it.
- **Gate wiring** is a per-map `automated_density` row in
  `docs/data/world_building_visual_benchmark.json`, not a global automated check, so the gate
  names the failing metrics per map. `toompea_small_castle` is a benchmark row without a registry
  blueprint and is marked `missing`.
- **Baseline covers 28 maps**, the full `MapBlueprintRegistry`. The "29" above counted
  `toompea_small_castle`, which is not registered yet.
- **Tier spread** (`wealth_tiers`, `age_tiers`) is measured and reported but dormant
  (`tier_spread_active: false`) until R-981 lands the semantic fields.
- `tests/python/test_verify_world_building_visual_gate.py` is also touched: its complete-fixture
  test needed the new row, and two tests cover the density row.

## Second review (R-989, 2026-09-26)

Reviewer: Cursor Agent (independent of the R-982 implementation session).
Verdict: **PASS**. Numeric floors stay. No threshold amendment.

Checked `density_contract` in `docs/data/map_composition_thresholds.json` against this file
and `docs/reports/map_density_baseline_2026-09-26.md`.

### Floor arithmetic

Benchmark `kalev_smithy`: 143.4 dressing props / 1000 walkable cells, 24.5 decals / 1000,
21 kinds, largest kind share 26.8%. Confirmed against the 2026-09-26 audit (41 props and
7 decals over 286 walkable cells).

| Class | f | props | decals | kinds (21 x scale, floored) | kind-share cap |
|---|---:|---:|---:|---:|---:|
| interior | 0.50 | 71.7 | 12.2 | 10 (x 0.5) | 30 |
| dense_urban | 0.25 | 35.9 | 6.1 | 12 (x 0.6) | 30 |
| sparse_urban | 0.125 | 17.9 | 3.1 | 10 (x 0.5) | 35 |
| foreland | 0.0625 | 9.0 | 1.5 | 8 (x 0.4) | 40 |
| rural | 0.0625 | 9.0 | 1.5 | 8 (x 0.4) | 40 |

props/decals match `round(benchmark * f, 1)`. Fraction story (room clutter -> plot/yard
share -> precinct share -> field/shore share) is written in `derivation` and is not read
back from outdoor measurements. `lower_town_slice` production grace keeps 2.3 / 0.7 against
35.9 / 6.1 until R-986; the floors were not lowered to pass the live district.

Relief 0.3 m reuses the existing `elevation_range_min` default. Toompea and
`archbishops_garden` keep their stricter 2.5 m card values for the P1-036 band audit.
`max_identical_footprint_run` 3 follows the three R-003 house tiers. Tier-spread keys exist
and stay dormant (`tier_spread_active: false`) until R-981.

### Ground-cover citations (floors unchanged)

The numbers are justified. Two derivation labels should be read as follows, not as a reason
to retune:

- dense_urban 10 is the `market_civic_quarter` grass/service-margin band 10-20%
  (`docs/HISTORICAL_AUDIT.md`, H04, H09). The "H06-H07 market" shorthand points at the
  Town Hall landmark pair, not that grass band.
- sparse_urban 20 is the enrolled `monastery_quarter` `grass_pct` lower bound `[20, 35]`.
  The prose monastery card is 25-40% (H14). The floor follows the machine band, not the
  outdoor 23.4% cover. Reconciling the 5-point card-vs-prose gap is a P0-072 hygiene item,
  not a WB-10 retune.
- foreland/rural 50 is the `viru_gate_foreland` meadow/pasture/field/woodland band 50-70%.
  Register H18 is livestock bones, not that grass band. Harbour cards sit at 20-35% and
  30-45% grass/scrub; keeping 50 is the stronger grassy-foreland/rural floor, not a fit to
  current outdoor maps (`world.padise` fails at 39.0%).

### Map classes

`archbishops_garden` is `sparse_urban` (precinct garden, not a street grid). `world.paide`
and `world.parnu` are `rural`. Other assignments match the registry: interiors, four dense
urban wards, monastery/Toompea as sparse urban, both harbours plus Viru as foreland, remaining
`world.*` as rural.

### Metrics and AR-13 seam

Walkable cells, dressing-only props (trees/bushes excluded), decals, kind share,
`ground_cover_pct`, relief span, and rotation-agnostic adjacent footprint runs are dressing
and ground. AR-13 (R-971) still owns appearance repetition, silhouette tuples, part-reuse
and landmark uniqueness. Nothing here duplicates those.

### Verify

- `python3 -m unittest tests.python.test_verify_map_composition tests.python.test_verify_world_building_visual_gate -v`
- `python3 tools/verify_map_composition.py` (no `--write-baseline`)
- `python3 tools/verify_world_building_visual_gate.py` remains `BLOCKED` and names density
  metrics per map
- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_composition_density`
  in an isolated HEAD worktree (shared tree already held Godot `--editor` and another harness)

Recorded 2026-09-26: unittest 25/25; composition verifier exit 0 (28-map table matches the
checked-in baseline); visual gate `BLOCKED` with 908 findings, including named density
metrics per map; Godot filter 8/8.
