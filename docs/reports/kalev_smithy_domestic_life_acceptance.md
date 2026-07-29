# Kalev smithy domestic-life acceptance (P2-062)

Recorded: 2026-07-30
Map: `loc.kalev_smithy` / `content/maps/kalev_smithy.rrmap`
Scope: polish and acceptance for player-driven household vignettes after P2-059 / P2-060 / P2-061

## Decision summary

1. **Presentation host:** `SmithyDomesticLifePresenter` owns temporary held props, one action-effect root, restrained `SkeletonModifier3D` contact poses, and at most two one-shot audio voices. Movement stays player-owned; story controllers keep priority.
2. **Station locks:** `SmithyStationReservations` keys exclusive workstations by authored `prop_id` so Kalev, Mart, and Henning cannot share the domestic hearth, anvil, or other exclusive props across separate routine controllers.
3. **Audio:** restrained procedural one-shots (water, fire/cooking, crockery, broom/textile, bellows, metal, quench) avoid shipping a new recorded SFX pack in this pass.
4. **Persistence:** active vignette remaining time, presenter snapshot, and Henning visitor pose round-trip through `MapStableStateStore` object deltas `runtime.smithy_domestic_vignette` and `runtime.smithy_henning_visit`.
5. **Acceptance bar:** accelerated 20-minute soak is deterministic, ends with zero active reservations, records station contention, and visits every slice phase.

## Verification

| Check | Result |
|---|---|
| `--filter=test_kalev_smithy_domestic_life` | 5/5 |
| `--filter=test_smithy_kalev_routine` | 8/8 |
| `--filter=test_smithy_henning` | 5/5 |
| `--filter=test_smithy_ambient_actors` | 4/4 |
| `--filter=test_smithy_routine_controller` | 10/10 |
| Soak (`SOAK_SECONDS=1200`) | deterministic; `active_reservations=0`; `prevented_contention_count>0`; `max_simultaneous_reservations<=1`; all five `SLICE_PHASES` visited |
| Day/night captures | `docs/reports/images/kalev_smithy_domestic_life/kalev_smithy_day.png`, `..._night.png` via `tools/capture_kalev_smithy_domestic_life.gd` |

## Capture review notes

- Day frame: living bay (hearth / table / wash) reads lighter and distinct from the smoke-darkened forge bay; bed, ledger, anvil, and courtyard door remain unobstructed.
- Night frame: domestic hearth / forge light hierarchy remains readable; zone boundaries stay legible under the P0-141 grade.
- Transitions from household beats to forge work remain optional vignettes; skipping them never blocks commission, dialogue, bed, or phase progression.

## Non-goals deferred

- Full bespoke animation clip library under `assets/animations/` (station profiles reuse shared-rig clips plus contact pose offsets).
- Recorded forge SFX pack under `sounds/forge/` (procedural one-shots meet the restrained audio verify for this pass).
- Autonomous NPC hunger or mandatory chore systems.
