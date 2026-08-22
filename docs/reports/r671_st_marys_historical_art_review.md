# R-671 St Mary's Cathedral historical and art review

**Review date:** 2026-08-22
**Task:** R-671 / human historical and art sign-off for R-291
**Parent:** R-291 / P4-025b
**Historical target:** Danish-ruled Toompea, Spring 1343, before the 16 May handover
**Inputs:** [`toompea_1343_art_brief.md`](toompea_1343_art_brief.md), [`toompea_1343_acceptance.md`](toompea_1343_acceptance.md), R-006 [`toompea-castle-and-upper-town.md`](../../history/dossiers/architecture/toompea-castle-and-upper-town.md), and the religion dossier [`churches-and-religious-houses.md`](../../history/dossiers/religion/churches-and-religious-houses.md)
**Status:** **BLOCKED - implementation and packet reviewed; no human historical or art approval issued**

## Decision

The R-291 St Mary's implementation and its paired day/night evidence satisfy the available source and structural review boundary. No concrete correction to the 1343 construction-site direction was identified in this review.

This is a **conditional art-direction pass**, not a human sign-off. The task remains open because the repository has no named human canon reviewer or named human art reviewer for this pair. Automated tests, source inspection, and an agent visual spot-check cannot substitute for the requested human historical/art approval.

## Required 1343 read

| Review requirement | Evidence and observation | Result |
|---|---|---|
| Standing choir | Runtime renderer owns a separate `StandingChoir` limestone mass with `StandingChoirRoof`. The close-up pair is linked below for gameplay-scale inspection. | **PASS as implementation evidence** |
| Standing vestry | Runtime renderer owns a separate `StandingVestry` mass behind the choir. | **PASS as implementation evidence** |
| Open three-aisle nave | `OpenNave` is built independently from the choir. It uses low unfinished aisle walls and leaves the nave volume open above the construction line. | **PASS as implementation evidence** |
| Rectangular piers | Five bays of north/south `RectangularPier_*` masses are authored in the nave. | **PASS as implementation evidence** |
| Timber scaffolding | `NaveScaffolding` contains timber posts, platforms, and top rails across the unfinished nave. | **PASS as implementation evidence** |
| Cut stone and mason bench | `MasonsYard` contains `MasonBench` and `CutStone_*` blocks outside the nave. | **PASS as implementation evidence** |
| Gameplay-scale paired lighting | Both files decode as 1200 x 800 RGBA PNGs, are non-blank, and are byte-distinct. The day plate has a daylight value range and the night plate has a dark blue night value range. | **PASS for packet integrity; human readability pending** |

The accepted interpretation is a bounded plausible composite grounded in the attested Gothic enlargement programme. It must not be presented as a measured archaeological 1343 footprint.

## Explicit rejection checks

| Rejected form | Review result |
|---|---|
| Completed nave roof or completed nave vault | **No rejection observed.** The renderer uses open nave geometry, half-height aisle walls, and visible scaffolding rather than a completed basilica shell. |
| Later west tower | **No rejection observed.** The dedicated St Mary's construction path does not add a west-tower mass. |
| 1779 baroque spire or completed tourist silhouette | **No rejection observed.** The dedicated path has no spire or later cathedral skyline component, and the source boundary test found no `1779`, `baroque spire`, or `Pikk Hermann` token in the implementation. |

The negative checks are implementation/source checks, not a substitute for a human close-up silhouette review.

## Evidence inventory

| Evidence | Result | Boundary |
|---|---|---|
| [`st_marys_1343_day.png`](images/toompea_1343/st_marys_1343_day.png) | Present, 1200 x 800 RGBA, non-blank | Documentation/runtime evidence plate supplied by R-291; visual approval not inferred |
| [`st_marys_1343_night.png`](images/toompea_1343/st_marys_1343_night.png) | Present, 1200 x 800 RGBA, non-blank and distinct from day | Documentation/runtime evidence plate supplied by R-291; visual approval not inferred |
| `test_toompea_quarter_prototype_map` | **8/8 pass** | Includes `test_toompea_st_marys_reads_as_1343_gothic_construction_site` and route/landmark checks |
| R-291 source implementation | **Pass for reviewed boundary** | Dedicated exceptional church path, stable `cathedral_silhouette` ID, and construction-phase metadata are present |
| Named human canon reviewer | **Not assigned** | Blocking absence |
| Named human art reviewer | **Not assigned** | Blocking absence |

## Required human closeout

A named human canon reviewer and a named human art reviewer must inspect the two linked plates at gameplay scale and record:

1. that the choir and vestry read as standing while the nave remains visibly open;
2. that rectangular piers, scaffold, cut stone, and mason bench remain legible under both lighting states;
3. that no finished nave roof, later west tower, 1779 baroque spire, or completed tourist silhouette is present;
4. any concrete amendment, with an owner, if a required feature is not readable at the review scale.

Until those fields are filled, R-671 remains **BLOCKED** and R-291 must remain in review. Do not promote this report to a human signature by treating the automated 8/8 result as approval.

## Verification record

Commands run from the project root on 2026-08-22:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/rebel-reval-r671
./tools/run_godot_checked.sh --require-test-summary \
  r671-toompea-map -- "$GODOT_BIN" --headless --path . \
  --script tools/run_godot_tests.gd -- --filter=test_toompea_quarter_prototype_map
# 1 file, 8 tests, 0 failures, 0 errors
```

The checked run also emitted the known Godot shutdown ObjectDB/resource-leak diagnostics after the green summary. They did not affect the eight assertions.

The independent image check reported:

```text
st_marys_1343_day.png: (1200, 800) RGBA mean=(164.32, 169.09, 172.15)
st_marys_1343_night.png: (1200, 800) RGBA mean=(31.86, 36.89, 51.8)
R671_ST_MARYS_PLATES_PASS
R671_ST_MARYS_SOURCE_BOUNDARY_PASS
```

## Sources

- [`toompea_1343_art_brief.md`](toompea_1343_art_brief.md)
- [`toompea_1343_acceptance.md`](toompea_1343_acceptance.md)
- [`../../history/dossiers/architecture/toompea-castle-and-upper-town.md`](../../history/dossiers/architecture/toompea-castle-and-upper-town.md)
- [`../../history/dossiers/religion/churches-and-religious-houses.md`](../../history/dossiers/religion/churches-and-religious-houses.md)
- [`../../scripts/map/view3d/map_view_mesh_builder_buildings.gd`](../../scripts/map/view3d/map_view_mesh_builder_buildings.gd)
- [`../../tests/godot/test_toompea_quarter_prototype_map.gd`](../../tests/godot/test_toompea_quarter_prototype_map.gd)
