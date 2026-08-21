# P0-102 Clean Elevation Recheck

**Task:** R-666 / P0-102 decomposition: rerun clean regression after elevation handoff
**Parent:** R-110 / P0-102
**Date:** 2026-08-22
**Base revision:** `981ecaa3c3ecbf1974255ef4ec3efd870dfe64be` (`Build St Mary's as a 1343 construction site`)
**Verification worktree:** `/tmp/rebel-reval-r666-20260822` (detached base plus the scoped elevation handoff patch)
**Scoped patch:** `/tmp/r666-elevation.patch` (SHA-256 recorded below)
**Decision:** **BLOCKED - elevation parser handoff is green, but the clean runtime matrix remains blocked by pre-existing shader, parity, and provenance findings**

## Scope and clean-snapshot method

The shared project worktree contains unrelated staged, unstaged, and untracked WIP. It was not used as the acceptance checkout. A detached worktree was created from the exact base revision above, then only the four files needed to exercise the available R-453/R-455 elevation handoff were applied:

- `scripts/map/rrmap/map_rrmap_parser_statements.gd`
- `scripts/map/rrmap/map_rrmap_serializer.gd`
- `scripts/map/map_blueprint_compiler_build.gd`
- `tests/godot/test_map_rrmap_parser.gd`

The authored `elevation_area` and `elevation_ramp` statements are already present in the base revision's `content/maps/lower_town_slice.rrmap`; no map content, parity fixture, runtime asset, provenance manifest, or unrelated test was changed. The temporary worktree was not used to create a commit and was not copied back into the project.

The scoped patch SHA-256 is:

```text
51db7fd87da85836cfc9bb965141a89a1481d101aad21913b40270a3293adfef
```

## Exact commands

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export WT=/tmp/rebel-reval-r666-20260822
export LOG=/tmp/r666_checked
export PATCH=/tmp/r666-elevation.patch

rm -rf "$WT" "$LOG" "$PATCH"
mkdir -p "$LOG"
git diff --binary -- \
  scripts/map/rrmap/map_rrmap_parser_statements.gd \
  scripts/map/rrmap/map_rrmap_serializer.gd \
  scripts/map/map_blueprint_compiler_build.gd \
  tests/godot/test_map_rrmap_parser.gd > "$PATCH"
git worktree add --detach "$WT" 981ecaa3c3ecbf1974255ef4ec3efd870dfe64be
git -C "$WT" apply "$PATCH"

# Import before tests.
"$GODOT_BIN" --headless --editor --import --path "$WT"

for filter in \
  test_environment_kit_integration \
  test_lower_town_slice_map \
  test_map_view_3d_fortification; do
  GODOT_LOG_DIR="$LOG" "$WT/tools/run_godot_checked.sh" \
    --require-test-summary "r666-${filter#test_}" -- \
    "$GODOT_BIN" --headless --path "$WT" \
    --script tools/run_godot_tests.gd -- --filter="$filter"
done

# Elevation-specific parser regression, run separately so its result is visible
# even when the checked runner rejects unrelated startup diagnostics.
GODOT_LOG_DIR="$LOG" "$WT/tools/run_godot_checked.sh" \
  --require-test-summary r666-map-rrmap-parser -- \
  "$GODOT_BIN" --headless --path "$WT" \
  --script tools/run_godot_tests.gd -- --filter=test_map_rrmap_parser

python3 "$WT/tools/verify_asset_lint.py"
python3 "$WT/tools/validate_asset_sources.py"
```

The raw Godot editor import returned status `0`, but it emitted missing-resource parse diagnostics. The checked import reproduction, which correctly rejects those diagnostics, was:

```sh
GODOT_LOG_DIR=/tmp/r666_checked "$WT/tools/run_godot_checked.sh" \
  r666-clean-import-checked -- "$GODOT_BIN" --headless --path "$WT" \
  --editor --import --quit
```

It returned status `1` because the clean base does not contain two shader files required by `shared_character_rig.gd`.

## Results matrix

| Check | Result | Exact result / retained evidence |
|---|---|---|
| Detached worktree from base revision | **PASS** | `/tmp/rebel-reval-r666-20260822`, base `981ecaa3c3ecbf1974255ef4ec3efd870dfe64be`; `worktree.log` |
| Scoped elevation handoff applied | **PASS** | Four allowlisted files only; `apply.log`; patch SHA-256 above |
| Godot raw editor import | **PROCESS PASS / ACCEPTANCE BLOCKED** | Exit `0`, but `/tmp/r666_checked/import.log` reports missing `eye_material.gdshader` and `hair_material.gdshader` preloads |
| `test_map_rrmap_parser` | **PASS** | `16 test(s), 0 failure(s), 0 error(s)`; includes elevation parse/compile/canonical round-trip and overlap-order tests |
| `test_environment_kit_integration` | **ASSERTIONS PASS / CHECKED BLOCKED** | `5 test(s), 0 failure(s), 0 error(s)`, but checked runner exit `1` because the log contains the unrelated shared-character shader parse errors |
| `test_lower_town_slice_map` | **BLOCKED** | `19 test(s), 1 failure(s), 0 error(s)`; only failure is canonical parity fixture drift in `test_lower_town_slice_matches_canonical_parity_fixture` |
| `test_map_view_3d_fortification` | **ASSERTIONS PASS / CHECKED BLOCKED** | `8 test(s), 0 failure(s), 0 error(s)`, but checked runner exit `1` because the log contains the unrelated shared-character shader parse errors |
| Asset lint | **PASS** | `asset lint passed (8 style-lock textures, 13 character glbs, 41 tier-classified character glb(s), 0 portrait(s) checked)` |
| Asset provenance | **BLOCKED** | Ten active plot-dressing albedo sidecars are missing `assets/SOURCES.csv` rows; see ownership below |

## First substantive diagnostics and ownership

### 1. Clean-base shader preload blocker

The first substantive diagnostic in the import and focused-suite logs is:

```text
SCRIPT ERROR: Parse Error: Preload file "res://scripts/characters/eye_material.gdshader" does not exist.
SCRIPT ERROR: Parse Error: Preload file "res://scripts/characters/hair_material.gdshader" does not exist.
ERROR: Failed to load script "res://assets/characters/shared/shared_character_rig.gd" with error "Parse error".
```

Both shader files are untracked in the shared worktree and absent from the detached base. This is not an elevation or environment-kit failure. Existing owners are **R-122** for the eye shader and **R-124** for the hair shader. The checked runner intentionally rejects this diagnostic even though the affected test files still report zero assertion failures.

### 2. Elevation handoff result

The prior clean-base parser errors are absent after applying the scoped handoff:

```text
unknown command 'elevation_area'
unknown command 'elevation_ramp'
```

No matching diagnostic appears in any `/tmp/r666_checked/*.log`. The dedicated parser suite passes all 16 tests, including:

- `elevation_area`, `grade`, and `elevation_ramp` parsing into `MapBlueprint` and `MapDefinition`;
- canonical serialization and reparsing;
- fingerprint preservation;
- authored profile ordering for overlapping relief precedence.

This confirms the R-453/R-455 parser boundary is available in the tested handoff snapshot. It does **not** close R-453 or R-455, because their board tasks still own the broader elevation gameplay/readability acceptance.

### 3. Lower Town parity drift

`test_lower_town_slice_map` has one independent failure:

```text
FAIL ...::test_lower_town_slice_matches_canonical_parity_fixture
lower_town_slice gameplay data changed; regenerate only after reviewing the canonical diff
expected: "door_side": "north",
actual:   "footprint": [
```

The route, validation, navigation, water exclusion, gate, and stable-ID assertions pass. The parity fixture was intentionally not regenerated under R-666. Authored Lower Town layout ownership is **R-547**; focused route/parity verification is **R-552**. This remains a blocker until those owners review the canonical diff and update the fixture under their task contract.

### 4. Asset provenance drift

`validate_asset_sources.py` fails because the following ten active runtime files have no `assets/SOURCES.csv` rows:

```text
assets/props/architecture/houses/plot_dressing/plot_dressing_PlotDressingIron_albedo.png
assets/props/architecture/houses/plot_dressing/plot_dressing_PlotDressingOak_albedo.png
assets/props/architecture/houses/plot_dressing/plot_dressing_PlotDressingRope_albedo.png
assets/props/architecture/houses/plot_dressing/plot_dressing_PlotDressingShingle_albedo.png
assets/props/architecture/houses/plot_dressing/plot_dressing_PlotDressingStone_albedo.png
assets/props/architecture/houses/plot_dressing/plot_dressing_PlotDressingStoneDark_albedo.png
assets/props/architecture/houses/plot_dressing/plot_dressing_PlotDressingThatch_albedo.png
assets/props/architecture/houses/plot_dressing/plot_dressing_PlotDressingTimber_albedo.png
assets/props/architecture/houses/plot_dressing/plot_dressing_PlotDressingWattle_albedo.png
assets/props/architecture/houses/plot_dressing/plot_dressing_PlotDressingWoodLight_albedo.png
```

The plot-dressing bundle belongs to **R-212** and repository-wide reconciliation belongs to **R-641**. R-666 does not add manifest rows or edit assets.

## Decision and handoff

R-666 is complete as a clean-baseline evidence report, but the P0-102 runtime matrix remains **BLOCKED**:

1. The elevation parser handoff is green and no longer produces the prior `elevation_area` / `elevation_ramp` unknown-command cascade.
2. Clean checked import is blocked first by missing R-122/R-124 shader assets.
3. Lower Town parity has one independent fixture mismatch; the fixture was not regenerated.
4. Asset provenance has ten active plot-dressing sidecars without manifest rows.
5. Environment-kit and fortification assertions are green in their isolated summaries, but their checked runs cannot be accepted while the clean import emits the shader parse errors.

No runtime code, map content, asset, provenance manifest, parity fixture, or parent status was changed by R-666. No duplicate follow-up task is created because every remaining finding has an existing owner.

## Evidence files

- `/tmp/r666_checked/import.log`
- `/tmp/r666_checked/r666-map_rrmap_parser.log`
- `/tmp/r666_checked/r666-environment_kit_integration.log`
- `/tmp/r666_checked/r666-lower_town_slice_map.log`
- `/tmp/r666_checked/r666-map_view_3d_fortification.log`
- `/tmp/r666_checked/asset-lint.log`
- `/tmp/r666_checked/asset-provenance.log`
- `/tmp/r666_checked/r666-clean-import-checked.log`
- `/tmp/r666-elevation.patch`

**Final status:** **BLOCKED - keep P0-102 open; rerun this matrix from a fresh clean snapshot after R-122/R-124 shader assets and the remaining owned baselines land.**
