# R-673 / R-281 St Olaf capture and silhouette acceptance

**Review date:** 2026-08-22
**Parent:** R-281 / P4-023c
**Map:** `monastery_quarter`
**Stable IDs:** `st_olaf_silhouette`, `st_olaf_frontage`
**Status:** **BLOCKED - evidence packet complete; named human historical/art review is still required**

## Decision

The current R-281 implementation passes its structural boundary and now has a reproducible matched day/night gameplay-scale packet. The packet is sufficient for a named human canon and art reviewer to inspect the St Olaf silhouette. This report does not invent a human signature: the final acceptance remains blocked until the named reviewers record their observations below.

## Historical and art boundary

| Requirement | Implementation/evidence | Result |
|---|---|---|
| Compact Spring 1343 mass | `st_olaf_silhouette` uses `st_olaf_1343`, metadata `historical_phase=compact_1343_mass` | **PASS as implementation evidence** |
| Massive west tower | `WestTower/Masonry` is authored separately and rises above the nave mass | **PASS as implementation evidence** |
| Completed vault cues | `VaultButtress_*` and `VaultLancet_*` nodes are present on the dedicated church path | **PASS as implementation evidence** |
| Ordinary-house separation | Renderer category is `church`; no ordinary `Roof` or `Chimney` nodes | **PASS as implementation evidence** |
| Later chancel omitted | `15thCenturyChancel` is absent; excluded feature metadata records `15th_century_chancel` | **PASS as source/runtime evidence** |
| Later basilica omitted | `Basilica` is absent; excluded feature metadata records `later_basilica` | **PASS as source/runtime evidence** |
| Giant spire omitted | `GiantSpire` is absent; excluded feature metadata records `giant_spire` | **PASS as source/runtime evidence** |
| Matched gameplay-scale day/night pair | `st_olaf_day.png` and `st_olaf_night.png`, same `framing_key`, 1280x720, gameplay orthographic size 33.75 | **PASS as packet integrity; human readability pending** |
| Route and occlusion review | Camera is focused on the authored `st_olaf_frontage` approach; no route/collision mutation is made by the view-only capture | **PASS as capture scope; visual/occlusion sign-off pending** |
| Performance budget | No dedicated R-281 benchmark or capture-time budget record exists in this acceptance packet | **BLOCKED** |
| Named human canon reviewer | No reviewer name or dated observation recorded | **BLOCKED** |
| Named human art reviewer | No reviewer name or dated observation recorded | **BLOCKED** |

## Evidence inventory

| Evidence | Result | Boundary |
|---|---|---|
| [`st_olaf_day.png`](images/st_olaf_r281/st_olaf_day.png) | Present, 1280x720 RGBA, non-blank | Gameplay-scale packet plate; not a human approval |
| [`st_olaf_night.png`](images/st_olaf_r281/st_olaf_night.png) | Present, 1280x720 RGBA, non-blank and matched to day | Gameplay-scale packet plate; not a human approval |
| [`capture_manifest.json`](images/st_olaf_r281/capture_manifest.json) | Stable-ID-linked metadata, map fingerprint, renderer, camera, focus, and pair framing key | Reproducibility evidence only |
| `test_st_olaf_church.gd` | Structural renderer test passes | Does not substitute for visual review |
| `test_st_olaf_r281_acceptance.gd` | Packet manifest/output contract | Does not substitute for human review |
| `st_olaf_frontage` | Authored approach anchor in `monastery_quarter.rrmap` | Stable route reference for reviewers |

## Required human review

A named human canon reviewer and a named human art reviewer must inspect both linked plates at gameplay scale and fill this record:

| Role | Reviewer | Date | Observation | Verdict |
|---|---|---|---|---|
| Human canon reviewer | **Not assigned** | - | Confirm compact 1343 mass, west tower, completed-vault cues, and absence of later chancel/basilica/giant spire. Record any historical amendment and owner. | **BLOCKED** |
| Human art reviewer | **Not assigned** | - | Confirm church reads as an exceptional landmark rather than a scaled house; assess silhouette, limestone/tile value separation, day/night legibility, frontage occlusion, and concrete amendments. | **BLOCKED** |

Do not change either row to PASS based on the automated tests or an agent visual spot-check.

## Verification record

Commands run from the project root on 2026-08-22:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/rebel-reval-r673

# Reproducible non-headless gameplay-scale pair.
"$GODOT_BIN" --path . --rendering-method gl_compatibility \
  --rendering-driver opengl3 --script tools/capture_st_olaf_r281.gd

# Focused structural and packet contracts.
./tools/run_godot_checked.sh --require-test-summary r673-st-olaf \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd \
  -- --filter=test_st_olaf_church
./tools/run_godot_checked.sh --require-test-summary r673-st-olaf-packet \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd \
  -- --filter=test_st_olaf_r281_acceptance
```

Recorded result:

```text
R-281 capture packet: PASS (pair written, stable-ID manifest, 1280x720 day/night)
R-281 structural boundary: PASS (st_olaf_1343 renderer contract, 1/1)
R-281 packet contract: PASS (2/2)
R-281 monastery route/transition suite: PASS (10/10)
R-281 human historical/art sign-off: BLOCKED (reviewers not assigned; R-492 owns the shared sign-off gate)
R-281 performance budget evidence: BLOCKED (R-490 owns the shared route/occlusion/budget gate)
```

No duplicate follow-up tasks are created: the missing human review is owned by R-492 / P0-101g, and route/occlusion/budget evidence is owned by R-490 / P0-101e. R-673 remains in review until those shared gates record the St Olaf row.

Known Godot shutdown-only resource/RID leak diagnostics after green summaries remain DEF-002 noise and are not used as visual acceptance evidence.

## Sources

- [`../../scripts/map/view3d/map_view_mesh_builder_churches.gd`](../../scripts/map/view3d/map_view_mesh_builder_churches.gd)
- [`../../tests/godot/test_st_olaf_church.gd`](../../tests/godot/test_st_olaf_church.gd)
- [`../../tools/capture_st_olaf_r281.gd`](../../tools/capture_st_olaf_r281.gd)
- [`../../tests/godot/test_st_olaf_r281_acceptance.gd`](../../tests/godot/test_st_olaf_r281_acceptance.gd)
- [`../../content/maps/monastery_quarter.rrmap`](../../content/maps/monastery_quarter.rrmap)
- [`../../history/dossiers/religion/churches-and-religious-houses.md`](../../history/dossiers/religion/churches-and-religious-houses.md)
