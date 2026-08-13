# R-454l - Historical elevation acceptance gate

**Review date:** 2026-08-13
**Task:** R-504 / R-454l
**Status:** **ACCEPTED - runtime, parser, gameplay-invariant, and rendered-readability gates pass**
**Review mode:** reproducible contract-gate run with non-headless Metal evidence; no human historical or art sign-off is claimed

## Decision

The R-454 historical-elevation runtime gate is accepted for R-504. The R-454 source matrix, all nine urban exterior RRMap profile sets, parser/compiler regression gate, R-503 gameplay-invariant gate, and the R-455 rendered-readability gate now have attributable passing evidence.

This closes the previously pending R-455 boundary without treating a data-only pass as visual acceptance. The remaining boundary is human historical/art review, which is outside this automated gate and must not be inferred from the PNG existence checks.

## Scope checked

- R-454 urban exterior matrix: nine maps, with `viru_gate_foreland` explicitly excluded.
- R-503 gameplay invariants: elevation remains view-only and must not change terrain, navigation, transitions, or gameplay snapshots.
- R-455 readability contract: deterministic height, water/shore adjacency, patrol/camera metadata, recessed water geometry, and matched Metal player-eye/top-down day/night evidence.

## Results

| Gate | Result | Evidence boundary |
|---|---|---|
| R-454 scope / R-522 | **PASS** | 1 file, 3 tests: all nine urban exterior maps compile within the matrix; five flat interiors remain flat; `viru_gate_foreland` remains explicitly excluded. |
| RRMap parser regression | **PASS** | 1 file, 16 tests: elevation grammar, compiled metadata, canonical round-trip, and rejection contracts pass. |
| R-503 gameplay invariants / R-523 | **PASS** | 1 file, 3 tests: elevation remains view-only, gameplay geometry/navigation snapshots stay identical, and reciprocal harbour transition identities plus physical seam spans remain aligned. |
| R-455 readability / R-524 | **PASS** | 1 file, 5 tests: runtime geometry contracts plus four validated 1600x900 Metal captures for Harbor North player-eye/top-down day/night views. |

The checked runner reported expected shutdown resource-leak diagnostics during the focused runs. They did not change the zero statuses and are not an acceptance blocker.

## Metal evidence

The four required plates are committed under `docs/reports/images/elevation/`:

- `reval_harbor_north_player_eye_day.png`
- `reval_harbor_north_player_eye_night.png`
- `reval_harbor_north_top_down_day.png`
- `reval_harbor_north_top_down_night.png`

Each was rendered in a separate non-headless Godot 4.7.1 process with `--rendering-method mobile --rendering-driver metal`. The saved logs identify `Metal 4.0 - Forward Mobile - Using Device #0: Apple - Apple M5 Pro (Apple9)`. The R-455 test verifies that each file exists, loads as RGB8, and has dimensions 1600x900.

## Runtime profile coverage

The current RRMap inventory contains the complete authored R-454 matrix in all nine urban exterior maps:

- `toompea_quarter`: plateau area, both Jalg ramps, southern slope
- `archbishops_garden`: plateau area, Toompea seam, center-gate taper, south-gate taper
- `reval_harbor_north`: Coastal Gate ramp, quay-to-wet-margin ramp, wet margin, harbour seam
- `reval_harbor_east`: Kalarand shore, shore track, village edge, north seam
- `lower_town_slice`: full Lower Town quartet
- `market_civic_quarter`: full market quartet
- `monastery_quarter`: full monastery quintet
- `north_quarter`: full north quartet
- `south_quarter`: full south quartet

`viru_gate_foreland` remains intentionally flat and outside the urban relief matrix. The legacy Monastery prototype fixture used by the R-455 compatibility test remains empty by design and is reported as a partial fixture boundary, not as a defect in the authored RRMap matrix.

## Acceptance boundary

R-504 is accepted for the reproducible runtime and renderer evidence gate. This report does not claim:

1. human historical validation of every profile target; or
2. final art-direction sign-off on exact pixel-level terrain/object alignment.

Those are review responsibilities rather than assertions that can be established by the Godot contract suite. No further R-455/R-504 runtime blocker remains from the evidence requirements in R-524.

## References

- [`r454_historical_elevation_profiles.md`](r454_historical_elevation_profiles.md) - frozen historical matrix and source confidence labels.
- [`r455_city_elevation_readability.md`](r455_city_elevation_readability.md) - runtime and rendered readability evidence.
- [`../../tests/godot/test_r454_elevation_scope.gd`](../../tests/godot/test_r454_elevation_scope.gd) - scope regression suite.
- [`../../tests/godot/test_r455_city_elevation_readability.gd`](../../tests/godot/test_r455_city_elevation_readability.gd) - readability/data and evidence-file contract suite.
- [`../../tests/godot/test_r503_elevation_gameplay_invariants.gd`](../../tests/godot/test_r503_elevation_gameplay_invariants.gd) - gameplay invariants and seam checks.
