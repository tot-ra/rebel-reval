# R-715 water exception matrix and external handoff

Recorded: 2026-08-29
Parent: R-715, reflective water rollout across authored maps
Scope: map-specific water exceptions, gameplay-topology parity, and external ownership boundaries
Status: **14/14 green for this verification slice; parent closeout remains blocked by R-713 weather evidence**

## Decision boundary

This report is a verification-only handoff. It does not repair map geometry, change activation policy, alter stable map/terrain/transition IDs, or accept visual/performance evidence. A row is green only when the compiled definition retains the expected closed water family and `MapView3D.create` leaves both the terrain fingerprint and gameplay walkability signature unchanged.

The focused exception test uses the exact 13 definitions listed in this report (the same sources represented by `MapAuditRegistry`), rather than traversing unrelated invalid prototype packages. It records every compiled definition containing one or more closed water IDs and fails if a listed definition disappears or changes family:

## Exception matrix

`enclosed` covers ponds, basins, and ditches using the still-water profile. `river` covers authored current/flow water. `shallow_coastal` and `deep_coastal` preserve the distinct coastal layers. `harbour` identifies the two Reval harbour landing maps as a gameplay-facing shoreline exception. `shoreline` marks a water-bearing row whose bank/shore presentation is map-owned and must remain view-only.

| Map ID | Closed water IDs | Exception classes | Shoreline case | Status |
|---|---|---|---|---|
| `smithy_courtyard` | `water` | `enclosed` | no | green |
| `lower_town_slice` | `water` | `enclosed` | no | green |
| `monastery_quarter` | `water` | `enclosed` | no | green |
| `south_quarter` | `water` | `enclosed` | no | green |
| `viru_gate_foreland` | `river_water` | `river` | no | green |
| `reval_harbor_north` | `shallow_water`, `deep_water` | `shallow_coastal`, `deep_coastal`, `harbour` | yes | green |
| `reval_harbor_east` | `shallow_water`, `deep_water` | `shallow_coastal`, `deep_coastal`, `harbour` | yes | green |
| `prototype.paldiski_coastal_outpost` | `shallow_water`, `deep_water` | `shallow_coastal`, `deep_coastal`, `shoreline` | yes | green |
| `prototype.sacred_grove` | `shallow_water` | `shallow_coastal`, `shoreline` | yes | green |
| `prototype.saaremaa` | `shallow_water`, `deep_water` | `shallow_coastal`, `deep_coastal`, `shoreline` | yes | green |
| `prototype.swedish_arrival` | `shallow_water`, `deep_water` | `shallow_coastal`, `deep_coastal`, `shoreline` | yes | green |
| `world.sacred_grove` | `shallow_water` | `shallow_coastal`, `shoreline` | yes | green |
| `world.padise` | `water`, `river_water`, `shallow_water` | `enclosed`, `river`, `shallow_coastal`, `shoreline` | yes | green |
| `world.saaremaa` | `shallow_water`, `deep_water` | `shallow_coastal`, `deep_coastal`, `shoreline` | yes | green |

The 14 rows above are the complete compiled water-bearing inventory. Prototype rows remain inactive where their authored definitions declare `active=false`; this matrix does not promote them. The two Reval harbour rows retain blocked water cells and map-owned landing/navigation boundaries. `world.padise` intentionally keeps pond, river, and shallow-water families together instead of collapsing them into one generic coastal category.

## External ownership

| Map ID | Note | Owner | Status |
|---|---|---|---|
| `monastery_quarter` | east ditch is now an `enclosed` row; travel openings stay dry | **R-529 resolved** | structurally green |

- **R-529 is resolved.** The Monastery east ditch stays in the authored water mask. A dirt causeway and the two outer travel openings are dry both as terrain IDs and as contour samples. See [`r529_monastery_east_ditch.md`](r529_monastery_east_ditch.md).
- **R-713 is the weather/presentation owner.** It owns unified sky/weather continuity and water-facing synchronization evidence. This report verifies topology only and does not duplicate or accept that presentation gate.
- R-755 remains the owner of renderer budget and target-hardware evidence; no headless result in this handoff is performance acceptance.

## Verification contract

Focused command:

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_r715_water_exceptions
```

The test enumerates `MapAuditRegistry.all()`, builds every compiled water-bearing definition, compares the closed family against this matrix, and checks that `MapView3D.create` preserves `MapTerrainGrid.fingerprint()` and the complete walkability signature. It also requires every matrix row and both external-owner markers in this report.

Relevant east-ditch command:

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_r529_monastery_east_ditch
```

Result in this checkout: R-529 is structurally resolved. Visual/performance packets may still omit monastery plates.

Report links resolve to repository files, and this report is intentionally separate from the visual acceptance packet: structural green status is not visual, weather, or performance acceptance.
