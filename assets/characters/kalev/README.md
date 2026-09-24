# Live Kalev entry (stable paths)

Production gameplay loads Kalev through these fixed paths only:

| Path | Role |
|------|------|
| `kalev.tscn` | Player-view rig: `fresh_rig.gd` + `kalev_rebuild/kalev_fresh.glb` + health ring |
| `kalev_variant.tres` | Stable identity `char.kalev` and shared-rig variant data |

Mesh, wardrobe `.tres` files, weapons, rebuild pipeline, and review scenes live under [`../kalev_rebuild/`](../kalev_rebuild/). Do not duplicate GLBs or garments here; map and save code depend on `res://assets/characters/kalev/kalev.tscn` staying thin.

Integration evidence: [`docs/reports/kalev_live_integration_2026-09-13.md`](../../../docs/reports/kalev_live_integration_2026-09-13.md).

Verification:

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_kalev_live_integration,test_character_rig
```
