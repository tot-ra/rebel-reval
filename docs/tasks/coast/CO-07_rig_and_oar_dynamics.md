# CO-07: Sails, oars and mooring lines answer the wind and the wave

Board row: **R-954**. Priority: high. Depends on: CO-06, CO-08.

## Player-facing goal

The harbour is alive in the wind. A set sail bellies out on the downwind side, flutters along its luff
when the wind eases, snaps taut in a gust and is furled to the yard in a storm. The yard braces round
as the wind shifts. Oars left in the tholes rock with the hull and drag their blades through the
passing wave crest; stowed oars stay put. Mooring lines go slack as a boat lifts on a crest and come
up taut in the trough, and a moored boat nudges against its pier fender. Pennants stream downwind.

## Why this is needed

`BoatFloat3D` already does the hull: it samples the WS-05 `OceanFftSampler` field at five points for
heave, pitch, roll and surge, and heels into `SkyWeather3D.wind_strength()` /
`wind_direction_xz()` with `WIND_HEEL_RAD` of 5.5 degrees. Nothing above the gunwale moves. The sail is
a static `_sail_mesh()` (merchant) or a `&"plaster"`-coloured furled spar (fishing), and the oars are
two fixed spars (`_add_oar`). So a storm that throws 1.26 m significant wave height at the hulls
leaves their rigs frozen, which is the strongest "these are props, not boats" signal on the map.

## Deliverable

1. `scripts/map/view3d/vessel_rig_dynamics.gd` (new): a per-hull rig controller, driven by the same
   `ocean_time` clock and the same `SkyWeather3D` wind that `BoatFloat3D` uses, so hull and rig never
   disagree. Inputs: wind vector, gust term, sea state (CO-08 Beaufort mapping), hull attitude and
   the hull's sampled wave height. Outputs, applied to the CO-06 named sub-nodes:
   - **Sail state machine**: `furled` / `reefed` / `set`, chosen from sea state with hysteresis so it
     does not flicker at a threshold. Storm furls; calm to fresh sets.
   - **Billow**: vertex or bone-driven camber on the segmented sail mesh, depth proportional to wind
     pressure, curved to leeward, with a luff flutter band whose amplitude rises as the apparent wind
     angle approaches the luff.
   - **Yard brace**: yard rotates to a plausible brace angle for the wind direction, clamped to the
     CO-05 range of motion, eased not snapped.
   - **Gust response**: a short taut/slack overshoot on the sheet and a brief heel spike, shared with
     the existing `WIND_HEEL_RAD` term rather than added on top of it.
2. **Oar dynamics**: oars in the tholes inherit hull attitude plus an independent blade-drag rocking
   term from the local wave height; a blade under the water surface is visibly wetted and pushes the
   WS-15 ripple sim. Stowed and hauled-up oars are static. Deterministic phase per oar per hull.
3. **Mooring lines**: line sag interpolates between slack and taut from the hull's instantaneous
   offset from its mooring point, and the hull's surge is clamped by line length so a moored boat
   cannot drift through its pier.
4. Pennant and any hanging net/line get the same wind direction, so nothing on a hull points the wrong
   way.
5. Budget: the whole rig pass for all hulls on a map stays under **0.3 ms** on the harbour scene, with
   full updates only for hulls inside a configured radius and a cheap reduced path beyond it.

## Allowed files

- `scripts/map/view3d/vessel_rig_dynamics.gd` (new + `.uid`)
- `scripts/map/view3d/boat_float_3d.gd` (rig hook and shared wind/gust term only)
- `scripts/map/view3d/map_view_mesh_builder_prop_models.gd` (attach the controller)
- `scripts/map/view3d/water_ripple_sim.gd` (oar-blade impulse only)
- `scripts/map/view3d/sky_weather_3d.gd` (gust accessor only, if one is missing)
- `tests/godot/test_vessel_rig_dynamics.gd` (new), `tests/godot/test_boat_float_3d.gd`,
  `tests/godot/test_water_ripple_sim.gd`
- `tools/capture_co07_rig_dynamics.gd` (new)
- `docs/reports/co07_rig_dynamics.md`, `docs/reports/images/co07_*.png`, `TODO.md`

## Constraints and non-goals

- No new vessel assets, no mesh authoring. CO-06 owns the meshes; this task only moves their nodes.
- No sailing, boarding or vessel control. Presentation only; no gameplay state, no save fields.
- No per-frame CPU readback from the GPU. The wave height already comes from the CPU-side
  `OceanFftSampler`.
- Deterministic: same map seed, same weather, same `ocean_time` gives the same rig pose. No
  unseeded randomness.
- Hull motion must not change. `BoatFloat3D` heave/pitch/roll/surge behaviour is regression-tested and
  stays as it is apart from sharing the gust term.
- Physically plausible beats dramatic. The sail may not invert, pass through the mast, or exceed the
  CO-05 brace range.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_vessel_rig_dynamics,test_boat_float_3d,test_water_ripple_sim
python3 tools/generate_active_docs_report.py --check
git diff --check
```

- `test_vessel_rig_dynamics.gd` asserts: sail state follows sea state with hysteresis and does not
  flicker across 600 frames of wind oscillating around a threshold; billow depth is monotonic in wind
  pressure and always to leeward; yard brace stays inside the CO-05 clamp; luff flutter amplitude
  rises as apparent wind angle approaches the luff; oar rocking correlates with the sampled local wave
  height and is zero for stowed oars; mooring line length clamps hull surge; determinism for a fixed
  `(seed, weather, ocean_time)`; the rig pass is under 0.3 ms for a full harbour hull count.
- `tools/capture_co07_rig_dynamics.gd` through `tools/godot_render.sh`: 10 s clips of the Kalamaja
  beach and the Harbor North roadstead at calm, fresh breeze, gale and storm, plus a wind-shift clip
  showing the yard bracing round, before and after, on Compatibility and Metal. The storm clip must
  show furled sails, and the fresh-breeze clip a bellied sail with a fluttering luff.
- `tools/run_performance_report.sh build/co07_perf.json --quick` inside the 16.67 ms budget.

## Doc updates

`docs/reports/co07_rig_dynamics.md`, `TODO.md`.

## TODO.md line

```
- [ ] R-954 | deps: R-953, R-955 | deliverable: VesselRigDynamics driving sail furl/reef/set with hysteresis, leeward billow, luff flutter, yard brace, gust taut/slack, wave-driven oar-blade rocking that feeds the WS-15 ripple sim, and mooring-line sag clamping hull surge, all off the shared wind and ocean_time clock | allowed files: per docs/tasks/coast/CO-07_rig_and_oar_dynamics.md | verify: `--filter=test_vessel_rig_dynamics,test_boat_float_3d,test_water_ripple_sim` incl. 600-frame no-flicker, leeward monotonic billow, brace clamp, stowed-oar zero motion, surge clamp, determinism and < 0.3 ms budget; calm/breeze/gale/storm and wind-shift clips before/after on Compatibility and Metal; quick performance report inside budget
```
