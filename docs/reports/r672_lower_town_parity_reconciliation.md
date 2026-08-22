# R-672 Lower Town parity fixture reconciliation

**Verification date:** 2026-08-22
**Map:** `lower_town_slice` / Workers' District
**Decision:** **PASS.** The authored R-547 Lower Town layout is authoritative for this follow-up; the canonical parity fixture now matches the compiled gameplay data.

## Scope

This closeout is limited to the canonical parity artifact and focused evidence. It does not change the authored RRMap, runtime map code, R-667 capture packet, house meshes, or provenance data.

The current `content/maps/lower_town_slice.rrmap` contains the already-authored R-547 rear property lanes, service-yard buildings, props, decals, and the R-607 stone-close overlay. Those records intentionally change gameplay walkability and terrain membership. The previous fixture therefore represented an older map revision rather than an authoritative baseline.

## Change

Regenerated `tests/fixtures/maps/lower_town_slice.parity.json` with the repository-owned generator:

```text
godot --headless --path . --script tools/regenerate_lower_town_slice_parity.gd -- --write-lower-town-slice-parity-fixture
```

Only the following canonical values changed:

| Field | Previous | Current |
|---|---:|---:|
| `navigation.walkability_sha256` | `57e9b9d32a01099e4c399e51b1552e5edbf6eba58d07eff5b6975d081bbbbf8f` | `0c33d876cd74bdd69c35cb4e91e4b1503112cb1adf690c2072219c72f85a4944` |
| `navigation.walkable_cell_count` | `13788` | `13982` |
| `terrain.terrain_id_grid_sha256` | `a9e0ea65b17c7ff1d3065c6d97f7743424f55e3dc414652e4a3074bbaac4d0ec` | `8174b29011ee0827976fbaf247bd2aab3d609935bfc34f690c300f5aa0dd859d` |
| `terrain.used_terrain_ids` | no `stone` entry | includes `stone` |

The generator changed 7 lines in the fixture and `git diff --check` reports no whitespace errors.

## Verification

After a Godot editor import refreshed the current parser/class cache:

```text
godot --headless --editor --import --path .
# completed import; only normal teardown resource-leak warnings were emitted

godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_lower_town_slice_map
# 1 file, 19 tests, 0 failures, 0 errors
```

The passing suite includes `test_lower_town_slice_matches_canonical_parity_fixture`, route reachability, wall/gate blocking, navigation generation, water exclusion, stable transitions, terrain composition, and view-only decal fingerprint checks.

## Boundary

R-667's capture packet remains untouched. The existing dirty-worktree parser/renderer WIP and unrelated generated files were not included in this change. The fixture is intentionally regenerated from the current authored R-547/R-607 map revision; future source layout changes must repeat the same review-first generator workflow.

## Sources

- [`Lower Town RRMap`](../../content/maps/lower_town_slice.rrmap)
- [`Lower Town parity fixture`](../../tests/fixtures/maps/lower_town_slice.parity.json)
- [`Parity generator`](../../tools/regenerate_lower_town_slice_parity.gd)
- [`Focused Lower Town map suite`](../../tests/godot/test_lower_town_slice_map.gd)
- [`R-547 task`](../../docs/reports/r587_lower_town_route_integration_verification.md)
