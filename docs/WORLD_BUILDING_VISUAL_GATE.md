# World-building visual benchmark and release gate

Task: `R-716`
Manifest: [`docs/data/world_building_visual_benchmark.json`](data/world_building_visual_benchmark.json)
Verifier: [`tools/verify_world_building_visual_gate.py`](../tools/verify_world_building_visual_gate.py)

## Purpose

The manifest is the repeatable acceptance contract for exterior world building. It keeps a fixed capture setup, a versioned comparison-sheet slot, a visual rubric, performance evidence, and a matrix row for every active or candidate exterior map. A map row is not promotable merely because it exists in the matrix.

The gate is intentionally fail-closed. Every required capture category, rubric decision, automated check, comparison sheet, and human art review must be accepted and point to repository-relative evidence before the verifier returns zero.

## Run the gate

```bash
python3 tools/verify_world_building_visual_gate.py
python3 tools/verify_world_building_visual_gate.py --json
```

The checked-in manifest currently returns `BLOCKED` because capture packets and human sign-offs are pending. That is the expected baseline until the corresponding evidence is authored. The JSON output is suitable for CI or a release wrapper.

## Fixed capture contract

Captures use `1920x1080`, the locked Art Bible day/night exposure presets, authored day and midnight time presets, clear and rain weather states, and deterministic wind seed `716`. Each exterior row must provide:

- `close_up`, `gameplay`, and `vista` composition views;
- `day`, `night`, `rain`, and `wind` temporal/weather views;
- `water`, `crowds`, and `characters` behavior/material views;
- `landmark_architecture` and `adjacent_map_traversal` acceptance views.

Evidence paths must remain repository-relative. The manifest also requires separate `minimum` and `recommended` performance evidence rows. Each row must include both `target_hardware` and `measurement_host` identities so a development-host result cannot be relabeled as target evidence. Host-specific raw performance JSON may live outside Git, but the row must link a retained release summary that identifies target hardware separately from the measurement host, following [`PERFORMANCE_REPORT.md`](PERFORMANCE_REPORT.md).

## Rubric and approval

Reviewers mark each row against geometry silhouette, PBR response, texture density, lighting and atmosphere, water, vegetation, animation/temporal behavior, historical coherence, repetition, seams, temporal stability, and performance tier. The human review requires a named reviewer, ISO date, and an evidence path. `approved` is distinct from an automated `pass` so automated checks cannot silently substitute for art-direction review.

The matrix is derived against active scene IDs in `content/transitions/active_destinations.json`, candidate maps in `docs/data/location_activation_manifest.json`, and Act 3 candidates in `docs/data/p6_002_activation_manifest.json`. Scene-style `world_*` IDs are normalized to the `world.*` RRMap namespace. Interior-only and landmark-only destinations are excluded from this exterior gate.

## Release decision

A map activation or promotion must stop when any of these are missing or non-accepted:

- water, atmosphere, vegetation, character, landmark, seam, or performance evidence;
- fixed-setting capture identity or comparison-sheet revision and ISO-8601 generation timestamp;
- automated map, transition, capture, or performance checks;
- the per-map `automated_density` row (WB-10 dressing-and-ground density contract);
- both minimum and recommended performance evidence with target/host identity;
- human art review.

This contract records readiness and blockers; it does not claim that the current prototype maps are visually accepted.

## Automated density row (WB-10)

Every map row carries `automated_density`, written by `python3 tools/verify_map_composition.py --write-baseline` from the compiled map: `status` (`pass`, `fail`, or `missing` when the source map is not in `MapBlueprintRegistry`), `evidence` (the dated baseline report), `source_map_id`, `map_class`, and `failing_metrics`. The gate blocks any row whose status is not `pass` and names the failing metrics in the error text and in `density_failures` of the `--json` output. This row measures dressing and ground only (props, decals, prop variety, ground cover, relief, identical adjacent footprints). Building appearance repetition is AR-13's row and is not duplicated here. Thresholds and their derivation: `docs/data/map_composition_thresholds.json` (`density_contract`); author guidance: `docs/MAP_AUTHORING.md`, section "Density and variety contract (WB-10)".
