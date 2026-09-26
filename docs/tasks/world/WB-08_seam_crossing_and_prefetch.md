# WB-08: Seam crossing with prefetch and eviction - no loading screen inside Reval

Board row: **R-980**. Priority: high. Depends on: **R-978**, **R-979**.

## Player-facing goal

The player walks from Kalev's smithy yard out into the Lower Town, south through the Karja opening
into the Southern Quarter, and on to the harbour, without a single loading screen or hitch. Taking
ship for Saaremaa or riding to Padise still shows an explicit travel transition, because those are
not adjacent places.

## Why this is needed

This is the row the maintainer actually asked for. R-978 gave it a persistent host, R-979 made
assembly payable in slices, and `MapWorldLayout` already derives deterministic global origins and
reciprocal seam records from authored transitions. What is missing is the policy: what to load,
when, and what to throw away.

## Deliverable

1. **A built world-layout manifest** for the `reval_outdoor` group, generated deterministically by
   `MapWorldLayout` from reciprocal physical transitions, reviewable, fingerprinted, and checked
   into the build rather than derived at runtime in load order. Records carry `world_group_id`,
   `location_id`, package path, fingerprint, signed `origin_cell`, local size, cell size, global
   half-open bounds, seam records, and location kind, as ADR 0019 section 1 requires.
2. **A streaming scheduler** on `WorldHost`: mount a neighbour when the player enters a prefetch
   band measured from the seam, evict when the player leaves a hysteresis band, with a residency
   cap so a long walk cannot mount the whole city. Bands and cap are project settings with stated
   defaults and a written derivation from the R-979 stage timings.
3. **Seam handover.** Crossing a seam changes the player's owning location without destroying the
   player, the camera, the environment or the HUD, and without a discontinuity in position,
   velocity, facing, camera framing or the day/night clock. Navigation paths cross the seam.
4. **The travel boundary enforced in code.** Any transition marked `alignment=travel`, and every
   location the R-977 membership list places outside the group, keeps the existing explicit
   transition. A travel transition that is mistakenly authored as a physical seam is rejected by a
   validator, not silently streamed.
5. **Fallback.** `world_host/scene_swap_fallback_enabled` remains a working path, so a failed mount
   degrades to today's transition instead of dropping the player into nothing.
6. **Flag default flips to on** only when the acceptance gates restated in R-977 all pass.

## Allowed files

`scripts/world/world_host.gd`, `scripts/map/map_world_layout.gd`,
`scripts/map/map_alignment_math.gd`, `scripts/map/map_chunk_runtime_index.gd`,
`scripts/map/map_object_chunk_streamer.gd`, `scripts/map/map_stable_state_store.gd`,
`scripts/global/door_navigator.gd`, `scripts/map/map_neighbor_preview_registry.gd`,
matching `.uid` sidecars, `project.godot`,
`content/world/reval_outdoor_layout.json` and its `.import` sidecar,
`tools/build_world_layout.gd` and its `.uid`, `tools/verify_world_layout.py`,
`tests/godot/test_world_seam_crossing.gd` and its `.uid`,
`tests/python/test_verify_world_layout.py`,
`docs/SEAMLESS_STREAMING_PLAN.md`, `docs/ARCHITECTURE.md`, `docs/MAP_AUTHORING.md`,
`docs/reports/seam_crossing_2026-09-26.md`, `docs/reports/images/seam_crossing/`,
`docs/tasks/world/WB-08_seam_crossing_and_prefetch.md`, `TODO.md`.

## Constraints and non-goals

Never persist chunk coordinates, node paths or instance IDs - ADR 0009 and ADR 0010 both forbid it,
and save identity stays `{location_id, object_id}` plus global cell/sub-cell. Do not merge `.rrmap`
files and do not author chunk IDs. Interiors follow whatever R-977 decided; do not silently change
that decision here. This row does **not** activate any map: activation stays gated by each map's
own task and by the world-building visual gate (`R-716`).

## Verification

- `godot --headless --path . --script tools/run_godot_tests.gd` with
  `test_world_seam_crossing.gd` asserting: the layout manifest is deterministic over 10 builds and
  cycle-free; a player crossing a seam keeps the same instance, position continuity within
  tolerance, and unchanged camera and clock state; prefetch mounts exactly the expected neighbours
  and eviction respects hysteresis; the residency cap holds on a full circuit; a `travel`
  transition never streams; a forced mount failure falls back to the scene swap.
- `python3 tools/verify_world_layout.py` and `python3 -m unittest tests.python.test_verify_world_layout -v`
- **Frame-time evidence for the headline claim**: a captured trace of a continuous walk across at
  least two seams showing no frame over the R-979 budget and no loading screen. A clip of the same
  walk is required, not optional.
- Save/load across a seam, and save/load while a mount is in flight.
- Keyboard, mouse and gamepad paths across a seam.
- Relief continuity: with R-976 landed, no vertical step at any crossed seam.
- `python3 tools/verify_map_audit.py`, `verify_map_activation.py`, `verify_map_conversion_plan.py`,
  `verify_map_composition.py`, `generate_active_docs_report.py --check`, `git diff --check`
- `tools/run_performance_report.sh` on minimum and recommended tiers, with the streaming residency
  cap at its default, inside budget.
- The ADR 0019 acceptance gates, as restated in R-977, all recorded as passed with evidence paths.

## Doc updates

`docs/ARCHITECTURE.md` and `docs/MAP_AUTHORING.md` record that a physical seam between two maps in
the same world group is now a runtime contract, and that `alignment=travel` is the only way to opt
a neighbour out.
