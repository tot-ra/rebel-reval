# R-999: map-pipeline parity and routes

Board row: **R-999**. Parent: **R-998**. Date: 2026-09-26.

## Decision

1. Restore the eight contract-owned rear-workshop building IDs and eleven
   service-yard props in `content/maps/lower_town_slice.rrmap`. Footprints
   come from `tests/fixtures/maps/lower_town_slice.parity.json` and
   `docs/reports/lower_town_p0_101_landmark_inventory.md`. Style
   `house.north.h96.44` matches `artisan_shed` so wall, roof, height, and
   door compile to the snapshot.
2. Keep `south_apron_scrub_b`, `south_apron_oak`, and `monastery_yard_linden`.
   They are already owned by `docs/data/lower_town_authoring_contract.json`.
   Retiring them would require a fixture regen for a deleted stable ID.
3. Treat `content/maps/toompea_small_castle.rrmap` as a WB-10 unregistered
   benchmark. `MapBlueprintAudit.UNREGISTERED_BENCHMARK_SOURCES` skips it in
   discover/audit. Do not register it from this tooling row.

## Reviewed fixture update

After the restore, compiled buildings, anchors, landmarks, transitions,
navigation (`walkable_cell_count` 13982 and `walkability_sha256`), and every
shared prop record match the previous fixture.

The remaining snapshot delta is:

- three contracted vegetation props listed above
- `terrain.terrain_id_grid_sha256`, which already differs on HEAD without
  the restored buildings (`8174b290...` -> `67e5905a...`). `used_terrain_ids`
  is unchanged. Walkability matches the old fixture, so this is a
  pre-existing paint-grid drift, not a walkable-area change.

The fixture is the Godot `MapParitySnapshot` serialization of that reviewed
state. It is not a blind regen to hide missing IDs.

## Verify

Isolated HEAD worktree plus these files:

- `--filter=test_map_pipeline_hardening` 2/2
- `--filter=test_lower_town_slice_map` expected 19/19 after the fixture
  update
- `tools/run_map_pipeline_ci.sh parity` and `routes`

`test_lower_town_service_yards` drainage IDs were restored in **R-1008**
(`decal.wet_service_gate` on the 66,72 gate opening, `decal.mud_carriers_lane`
on the 66,86 carriers-lane anchor, `decal.grime_service_firewood` on the
91,78 firewood stack). They are view-only; the R-999 parity fixture is
unchanged.
