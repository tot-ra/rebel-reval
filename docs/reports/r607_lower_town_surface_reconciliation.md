# R-607 Lower Town surface-share reconciliation

**Verification date:** 2026-08-19
**Map:** `lower_town_slice` / Workers' District
**Decision:** **PASS for surface substrate; BLOCKED for unrelated composition gates.**

## Change

The documented Lower Town bands remain unchanged and remain enforced:

| Metric | Required band/cap | Post-change measurement | Result |
|---|---:|---:|---|
| `stone_pct` | `25..40%` | `26.6815536608472%` | PASS |
| `earth_pct` | `35..50%` | `45.8722425226688%` | PASS |
| `grass_pct` | `15..30%` | `27.446203816484%` | PASS |
| `cobblestone_pct` | `<=40%` | `4.52023277845446%` | PASS |

The RRMap adds two named terrain-only overlays after the existing road and terrain layers:

- `lower_town_foreland_apron`: packed earth on the eastern traffic/service apron.
- `lower_town_stone_closes`: limestone/stone closes in institutional, yard, and edge spaces.

These overlays do not change building, prop, anchor, transition, route, or elevation records. The elevation metric remains `1.48229014535609`, and the existing elevation profiles remain view-only. The authoring contract now explicitly mirrors the enforced threshold card (`enforce=true`, `enforcement_state=enforced`).

## Verification

- `python3 -m unittest tests.python.test_verify_map_composition -v`: PASS, 5 tests.
- `tools/audit_map_composition.gd`: Lower Town surface-share and cobblestone checks no longer emit violations.
- Post-change `MapCompositionAudit.measure`: surface metrics above; `built_density_pct=21.9622960342187`, `max_style_share_pct=47.5409836065574`, and `largest_empty_region_cells=14778` remain outside separate R-600 bands and were not changed by this c1 task.
- Existing global audit still reports the Lower Town density/style/empty-region blockers and the unrelated `monastery_quarter` empty-region baseline. Those remain owned outside R-607.
- Canonical Lower Town parity was not regenerated because concurrent R-547 layout changes are still owned by R-606.

## Sources

- [`Lower Town RRMap`](../../content/maps/lower_town_slice.rrmap)
- [`Lower Town authoring contract`](../data/lower_town_authoring_contract.json)
- [`Composition thresholds`](../data/map_composition_thresholds.json)
- [`r598 surface/elevation verification`](r598_lower_town_surface_elevation_verification.md)
