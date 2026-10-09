# R-928 Air Gust gameplay-scale wedge

**Task:** R-928 (R-927 follow-up). **Status:** code done, plates pending.

`MapViewMagicVfx.play_knockback_cone` now draws the wedge and smoke at
`WEDGE_VISUAL_REACH_SCALE` (1.9x) of the true knockback radius, and the prism
height is 1.9 (was 1.35). The reach is view-only; `CombatKnockbackEffect` is untouched.

Verification: `--filter=test_magic_air_gust,test_map_view_magic_vfx` -> 9 tests, 0 failures
(new assertion: wedge AABB depth > 1.5x the true 3.5 world-unit radius).

Not done: the in-map recapture. `tools/capture_air_gust.gd` no longer parses because
`LowerTownSlice` / `WorkersDistrictBandit` were retired in 88b010506. Follow-up task
repoints the capture at a current map, then regenerates `images/air_gust/in_map_*.png`.
