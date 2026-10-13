---
name: rebel-map-authoring-rules
description: Mandatory rules and pre-commit gate for any Reval Rebel map blueprint, prefab, compiler/validator, transition registry, map audit, or MAP_AUTHORING.md change.
---

# Map authoring rules and gate

Read before touching map content. Full contract: [`docs/MAP_AUTHORING.md`](../../../docs/MAP_AUTHORING.md) and [ADR 0009](../../../docs/adr/0009-map-blueprint-authoring-architecture.md).

## Rules

- Author through `MapBlueprint` primitives and reviewed prefabs (`scripts/map/prefabs/urban_prefab_package.gd`). Do not add new giant `MapDefinition` dictionary factories. Existing ones get only narrow fixes.
- Register every blueprint explicitly in `scripts/map/map_blueprint_registry.gd` with its required gameplay anchors. Do not discover blueprints by walking the filesystem.
- Preserve every stable ID (map, transition, spawn, anchor, patrol, prop, structure, landmark, prefab instance, prefab-local). Moving, reordering, regenerating, or chunking must not rename IDs.
- Use typed primitive placement for one-off geometry and allowlisted prefab-child overrides for exceptions. Do not use raw runtime dictionaries.
- Generated terrain, collision, navigation, marker, and view nodes are disposable output. Fix the blueprint or compiler, not the nodes.
- Preview, runtime, chunking, navigation, and 3D must consume the same compiled `MapDefinition` fingerprint. Never persist chunk coordinates, node paths, or instance IDs.
- `MapBlueprintDiagnostic.code` values are a stable API. `error` rejects output. Review `warning` diagnostics (e.g. `MAP_GEOMETRY_OVERLAP`) with an explicit decision. Do not hide them.
- Migrate one map at a time. A migration is not done until the deterministic, semantic snapshot, collision/navigation, scene, and visual parity checks pass. Do not regenerate parity fixtures just to get green.
- Do not hand-edit giant city `.tscn` files without visual verification.

## Pre-commit gate

```bash
godot --headless --path . --script tools/validate_map_blueprints.gd
godot --headless --path . --script tools/run_godot_tests.gd
godot --headless --path . --script tools/build_world_layout.gd -- --check
python3 tools/verify_world_layout.py
python3 tools/verify_map_audit.py
python3 tools/verify_map_activation.py
python3 tools/verify_map_conversion_plan.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

Pipeline stages: `tools/run_map_pipeline_ci.sh parser|compiler|audit|persistence|parity|routes|benchmark-smoke`. Review `build/benchmarks/large-map-ci-smoke.json` after benchmark runs.
