# UF-08: Seam form continuity
Board row: **R-1117**. Priority: high. Depends on: **R-1114, R-980 / R-1043**.

## Player-facing goal

Crossing between streamed districts feels like one town: no ground step, street-axis or width jump, paving discontinuity, frontage kink, or broken wall/ditch line.

## Why this is needed

`MapAlignmentMath` already checks seam span and origin, with diagnostics `MAP_WORLD_SEAM_SPAN_MISMATCH` and `MAP_WORLD_SEAM_ORIGIN_CONFLICT`. `tools/verify_world_layout.py` verifies manifest integrity, group membership, package hashes, bounds/overlap, placement tree and edge/transition seam correspondence; the accepted streaming plan and WB rows prove navigation/residency. None checks authored form across the aperture: compiled ground-height deltas, street identity/class/width/surface correspondence, street continuations, frontage-line step, or wall/ditch continuity. These are genuinely new checks, not replacements for geometry alignment checks.

## Deliverable

Add `tools/verify_seam_continuity.gd` and `docs/data/seam_continuity_budget.json`. For each `reval_outdoor` seam in `content/world/reval_outdoor_layout.json`, compare cell-by-cell compiled output along the shared edge and report excessive ground-height delta, crossing street ID/class/width/surface mismatch, street terminating without counterpart, excessive frontage-line step, and discontinuous wall/ditch. Commit tolerances and measured existing failures with a grace entry per seam naming its remediation row. Fail closed; integrate with `tools/run_pre_commit_checks.sh` for map/layout changes and `tools/run_map_pipeline_ci.sh`.

The verifier is a **Godot tool script, not Python over compiled output**: the checks need compiled ground heights and semantic street/building/wall/ditch records, while `verify_world_layout.py` reads the checked-in JSON manifest and RRMap transition source, not authoritative compiled geometry. A Python verifier would need a second serializer/export contract and risk divergence from compiler semantics. A Godot script can load the registered MapBlueprints and inspect canonical MapDefinition records without adding another generated output format. The board row's first draft named a `.py` path; that was withdrawn on 2026-09-30 and R-1117 now specifies the Godot script below. Do not add a Python wrapper whose only job is to shell out to Godot.

## Allowed files

- `tools/verify_seam_continuity.gd`
- `docs/data/seam_continuity_budget.json`
- `tests/godot/test_seam_continuity.gd`
- `tools/run_pre_commit_checks.sh`
- `tools/run_map_pipeline_ci.sh`
- `.github/workflows/ci.yml`
- `docs/SEAMLESS_STREAMING_PLAN.md`
- `docs/MAP_AUTHORING.md`
- `TODO.md`

## Constraints and non-goals

No map content edits. Do not weaken the existing span/origin checks. Only seams within `reval_outdoor`; travel destinations remain outside per ADR 0019. Stable IDs and current manifests remain unchanged. Baseline failures get named grace rows, never hidden diagnostics. Respect MapBlueprint source, reviewed prefabs, explicit factory registration, disposable generated nodes and stable diagnostic codes.

## Verification

- `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_seam_continuity` with negative fixtures for a height step, a street width jump, an orphan street end and a broken wall run.
- `godot --headless --path . --script tools/verify_seam_continuity.gd` against the real repository, printing a per-seam table.
- Pre-commit fixture proves staged map change triggers the gate.
- Confirm CI lists and executes the gate.
- Retain `godot --headless --path . --script tools/build_world_layout.gd -- --check` and `python3 tools/verify_world_layout.py` to ensure the independent span/origin and manifest gates remain active.

## Doc updates

Update `docs/SEAMLESS_STREAMING_PLAN.md` to distinguish existing span/origin checks from form continuity checks and explain the verifier/compiler boundary. Resolve the Python-named board deliverable versus Godot implementation path before implementation; no alternate output format.

## TODO.md line

- [ ] R-1117 | deps: R-1114, R-980 / R-1043 | deliverable: fail-closed continuity gate for compiled form across reval_outdoor seams | verify: negative and real seam fixtures, pre-commit/CI integration, existing layout checks retained
