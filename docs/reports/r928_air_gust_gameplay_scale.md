# R-928 Air Gust gameplay-scale wedge

**Tasks:** R-928 (scale), R-1538 (capture repair).
**Status:** implemented (**R-1538**); current-city plates captured.
**Scope:** isolated 3D VFX review at the gameplay orthographic scale, not a physical-world spell unlock or spirit-arena art review.

`MapViewMagicVfx.play_knockback_cone` draws the wedge and smoke at
`WEDGE_VISUAL_REACH_SCALE` (1.9x) of the true knockback radius, and the prism
height is 1.9 (was 1.35). The reach is view-only; `CombatKnockbackEffect` is untouched.

## Current-city capture (R-1538)

`tools/capture_air_gust.gd` now uses `CityPlan.load_default()` and
`CityMapView.create_city()` instead of the retired `LowerTownSlice` factory.
The focus is the vertex average of the authored `space.forum` polygon in
`content/world/reval_city/plan.json` (world XZ approximately -3.83, -6.83).
Both actors are placed on the actual ground with `CityMapView.sync_actor`.
The camera explicitly uses orthographic projection, the gameplay size from
`CharacterScale`, and the shared map pitch/yaw. Date is 20 April 1343;
weather is clear and the day-cycle progress is fixed at 0.45.

The studio bandit uses `CombatRoomEnemy` with `EnemyArchetype.bandit()` rather
than the removed `WorkersDistrictBandit`. Existing studio filenames are
retained for compatibility; the accepted R-924 studio PNGs are unchanged.

Run from the project root (GPU renderer, minimized window):

```sh
tools/godot_render.sh --script tools/capture_air_gust.gd -- --skip-studio
```

Without `--skip-studio`, the tool also captures both studio triplets. The full
path was smoke-tested and the accepted studio files restored byte-for-byte.
The three refreshed 1440x810 city plates are:

- [Before](images/air_gust/in_map_lower_town_before.png)
- [Mid](images/air_gust/in_map_lower_town_mid.png)
- [After](images/air_gust/in_map_lower_town_after.png)

The `mid` wind wedge is advanced explicitly to 0.10 s and frozen during GPU
settling; `after` advances it past its 0.55 s lifetime. This prevents a slow
frame rate from deleting the effect before the screenshot. The target's
knockback still runs through the authored grant, resolver, executor and
`tick_ai` slide, not a staged displacement. The save waits for
`RenderingServer.frame_post_draw` before reading the texture.

## Verification and limits

On Godot 4.7.1, Mobile/Metal on macOS:

```sh
python3 -m gdtoolkit.linter tools/capture_air_gust.gd
python3 -m unittest tests.python.test_magic_air_gust_content -v
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- \
  --filter=test_map_view_magic_vfx,test_spirit_magic,test_magic_runtime
```

- GDScript lint passes; Python content validation: 6 tests, 0 failures.
- Current Godot coverage: 29 tests, 0 failures, 0 errors, including the
  9 VFX tests and the Air Gust spirit-duel test. The old
  `test_magic_air_gust.gd` no longer exists; the old 9/9 combined gate is stale.
- Mobile capture prints all three output paths and exits 0. The log still
  reports shutdown-only particle-shader/RID leaks; this is not a completely
  clean engine log. It has no runtime parser, cast or missing-resource errors.
- For visual review, compare the named fan and target movement across the
  linked triplet. Historical R-927 crop metrics are not a parity threshold:
  the backdrop changed from a retired district to the seamless city.
- Compatibility smoke writes plates but is **not accepted**: the full city
  exceeds the 4096 shader-instance budget and at least one material uses
  17 fragment samplers against a limit of 16. See follow-up **R-1690**;
  process exit 0 alone does not establish renderer correctness.
- This tool calls the low-level resolver/executor deliberately. Normal player
  casts remain spirit-world-only per [MAGIC.md](../SYSTEMS/MAGIC.md) and ADR 0033.
  It does not mount the cookbook, accept input, or write save state.
