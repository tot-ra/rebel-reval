# WR - Water realism v2 (task pack)

Status: in progress. Epic **R-1497**. WR-0..WR-2 implemented (R-1498..R-1500); WR-3..WR-10 planned (R-1508..R-1515). Owning feature pages: [City sea](../../SYSTEMS/CITY_SEA.md#water-realism-v2-wr-1-wr-2), [Water sandbox](../../SYSTEMS/WATER_SANDBOX.md).

## Request and decisions

Maintainer request (2026-10-09): the sea should be more realistic than the [Three.js Water Pro](https://www.threejswaterpro.com/) demo. Reported defects: sharp, spiky wave crests; unrealistic surf foam and spray; foam that "reads as a global texture layer drifting somewhere". Wanted: an industry-grade, efficient wave, foam and surf simulation that respects the seabed, rocks and obstacles; quality that scales with the graphics tier and camera distance; a sandbox testing cases alone and combined (light, wind, rain, gusts, rock and pebble sizes).

Decisions recorded in this pack:

- **No ADR.** This is a fidelity pass inside existing scope (ADR 0031 city sea, the WS water/sky pack); it adds no mechanic, area or pillar. Local simulations (WR-5, WR-7) follow the WS-15 ripple-sim precedent (GL-compatible SubViewport ping-pong, off on minimum tier).
- **City first.** Every change is gated on the city sea (`sea_physical_depth` instance flag, `shore_crest_shape`); district maps keep their look until a separate task ports it.
- **Sandbox is the acceptance bench.** Each WR task verifies with named sandbox plates or clips; the city capture tool remains the in-context check.
- The Three.js Water Pro page is a JS-rendered demo whose feature list could not be read by the tooling; the comparison is against the industry techniques below, not a feature-by-feature port.

## Root causes found (2026-10-09)

1. **Rectified sea.** The FFT vertex path clamped every trough to 1.5 mm below rest (`FFT_TROUGH_FLOOR`), a district-map guard for a recessed bed a few centimetres down. The city sea has metres of water under it, yet used the same floor: the surface became crests over a flat plane, with a slope kink at the clamp, which reads as sharp ridges.
2. **Aliased geometry.** Cascade C1 (4-16 m waves) displaced the city's 4 m open-sea grid, below Nyquist for its short end: triangular spikes and shimmering facets.
3. **Shore crest lip.** The analytic breaker's skewed `cos^(1+2s)` profile with a 0.4 face and full curl pushed the crest over its own face: a sharp lip on a 0.5 m mesh.
4. **Conveyor foam.** `_city_foam_pattern` scrolled all three foam layers downwind at a fixed world speed, independent of the water; the shore patch noise scrolled with `TIME`; the edge ribbons were travelling `sin()` bands. Nothing moved *with* the water.
5. **Saturated coverage.** The baked whitecap mask is broad (it carries every decaying patch); surf foam had a 2.2 gain and a lingering 0.25 floor over the 24 m surf zone, so most of the city sea was white in a fresh breeze (real whitecap cover there is about 1-3 %).

## Industry practice (what the pack implements)

| Problem | Practice | References | WR |
|---|---|---|---|
| Open-sea waves | FFT spectrum cascades, choppy displacement; only cascades the mesh can resolve displace it, finer ones go to per-pixel normals | Tessendorf, *Simulating Ocean Water* (SIGGRAPH course 2001); Unity HDRP Water System; Crest Ocean System | 1, 3 |
| Distance LOD | Camera-centred geometry clipmaps / CDLOD with vertex morphing between rings | Losasso & Hoppe, *Geometry Clipmaps* (2004); Strugar, *CDLOD* (2009) | 3 |
| Whitecaps | Foam where the displacement Jacobian folds, accumulated in a persistent buffer, advected and decayed; coverage tied to wind (Monahan & O'Muircheartaigh 1980: W = 3.84e-6 U^3.41) | Crest foam simulation; Sea of Thieves (Rare, SIGGRAPH 2018 talks) | 2, 7 |
| Foam look | Foam texture attached to the surface (Lagrangian UV), dissolved by a threshold as foam ages so it breaks into lace | common in AAA water shaders (Crest, HDRP, Atlas) | 2 |
| Surf | Depth-aware shoaling, refraction to shore-parallel crests, breaking at H/h ~ 0.78; breaker type from the Iribarren number (spilling / plunging / surging) | Battjes (1974); coastal engineering texts; Unreal Water shore waves | 4 |
| Obstacles | Local heightfield wave-equation / shallow-water simulation near the camera with an obstacle mask (reflection, diffraction); or wave particles / surface wavelets | Yuksel et al., *Wave Particles* (2007); Jeschke & Wojtan, *Water Surface Wavelets* (2018); Unreal Niagara shallow-water fluids | 5 |
| Spray | Particles emitted by breaking events and impacts, velocity-stretched droplets plus mist sheets | AC IV / Sea of Thieves breaker VFX | 6 |
| Wind and rain | Moving gust cells raise capillary roughness (cat's paws); rain rings and damped short waves | Beaufort sea descriptions; WS-15 rain rings | 8 |
| Beach response | Wet band from swash history; porous shingle drains the backwash | Tidewater port (WS-08) wetting history | 9 |

Constraint shared by all rows: Godot 4.7 **GL Compatibility** (no compute shaders, no tessellation). Simulations run as fragment-shader ping-pong in SubViewports; everything else is analytic or baked.

## Tasks

| Ref | Task | Status |
|---|---|---|
| R-1498 | WR-0 water sandbox: synthetic coast, case bays, light/wind/rain/gust matrix ([page](../../SYSTEMS/WATER_SANDBOX.md)) | implemented |
| R-1499 | WR-1 band-limited wave geometry: bed-relative troughs, no C1 on the 4 m grid, rounded spilling crest | implemented |
| R-1500 | WR-2 foam attached to the water: Lagrangian cells, swash surge, age dissolve, physical coverage; interim smaller lit spray | implemented |
| R-1508 | WR-3 camera-centred sea LOD with geomorphing, graphics-tier water presets | planned |
| R-1509 | WR-4 waves feel the seabed: shoaling, refraction, breaker type by Iribarren number | planned |
| R-1510 | WR-5 waves around rocks and obstacles: local GPU wave sim with obstacle mask | planned |
| R-1511 | WR-6 event-driven spray, splash and mist | planned |
| R-1512 | WR-7 persistent foam buffer (born, advected, decayed), high tier | planned |
| R-1513 | WR-8 wind gusts (cat's paws) and rain on the open sea | planned |
| R-1514 | WR-9 pebble and sand beach response | planned |
| R-1515 | WR-10 acceptance: sandbox matrix review, per-tier budgets, in-city check | planned |

Suggested order: WR-3 and WR-4 first (they unblock the rest), then WR-5 and WR-6 (obstacles and spray share impact events), WR-7, WR-8 and WR-9 in parallel, WR-10 last. Each task's allowed files, constraints and verification live on the task board.
