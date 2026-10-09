# Water sandbox

Status: implemented (task **R-1498**, WR-0 of the [water realism v2 pack](../tasks/water_sky/WR_water_realism_v2.md)). Scope: a developer test bed that runs the runtime city sea, surf, foam and spray on a synthetic coast, one bay per case, under a matrix of light, wind, rain and gust conditions. Out of scope: gameplay, saves, a playable scene, shipping assets.

## What it is

`tools/water_sandbox/water_sandbox.gd` builds a 6-bay coast (840 x 290 m, 2 m height cells) directly into a bare `CityPlan`, then runs the **runtime** water code on it: `CityTerrainBuilder` ground, `CityShoreField` bake and 0.5 m surf band, the `CityWorld3D` sea (static skirt plus the WR-3 camera-centred rings of `CitySeaLod`), `CityShoreSpray` and the shared FFT water material. No shader or parameter is copied, so a change seen in the sandbox is the change the city gets. The coast follows the city's orientation: shore at z = 0, sea to the north (-z).

| Case id | Bay | What it isolates |
|---|---|---|
| `sand` | 1:30 sand beach with an offshore bar and trough | spilling breakers, long run-up, surf foam bands |
| `shingle` | 1:8 shingle beach, small / medium / large pebble sections | steep surging swash, short run-up, pebble scale |
| `boulders` | 1:15 slope with 70 rocks of 0.3-3 m | obstacles in the swash; rocks of 1.6 m and more are stamped into the heightfield so the shore field and sea mesh treat them as hard edges |
| `stack` | rock platform with a 13 m sea stack and a headland ridge | slosh and foam around a large obstacle, hard-edge shore |
| `quay` | vertical wall into 4 m of water | reflection / slosh against a quay, no run-up |
| `reef` | sand beach behind a submerged band of 1.6-3.4 m rocks | combination case: breaking over the reef, then shore surf |

Rock and pebble meshes are the shipped CO-02 shore debris (`MapViewShoreDebris`), scaled to the target diameter. Placement is deterministic (seed 1343).

## How to run

GPU captures go through `tools/godot_render.sh` (minimised window, never a visible editor run):

```bash
tools/godot_render.sh --script tools/water_sandbox/capture.gd -- \
  --case=sand,reef --shot=close,side,wide,swim,open \
  --light=noon,sunset,night,overcast --wind=calm,fresh,gale [--rain] [--gust] \
  [--motion=N] [--dolly=M] [--advance=S] [--tier=minimum|recommended|high] [--bench=N] \
  [--size=1280x720] [--tag=x]
```

Every list argument is a comma list; the run renders the cross product. Output: `build/water_sandbox/<tag>/<case>_<shot>_<light>_<wind>[_rain][_gust].png`, plus `sheet.png`, a contact sheet of every plate. `--motion=N` adds N frames at 24 Hz per plate (`<plate>_motion/0000.png`...), to make a clip: `ffmpeg -framerate 24 -i <dir>/%04d.png -c:v libx264 -pix_fmt yuv420p out.mp4`.

- **Shots:** `close` (standing on the beach, looking out), `side` (along the waterline), `wide` (17 m up), `swim` (eye at the surface 32 m out, looking at the shore), `open` (3 m above deep water, looking out to sea). Stack and quay override `close`/`side` to frame the obstacle.
- **Light:** `noon` and `overcast` at day progress 0.5, `sunset` 24 min before the calendar sunset, `night` at 0.94; sky weather is pinned per plate.
- **Wind:** sea weather strength 0.10 / 0.55 / 0.95 (calm, fresh breeze, gale) from one fixed direction. `--rain` switches the sky to the rain preset and sets rain 0.8 on the sea and ground.
- **Tier:** `--tier` sets the FFT, SkyWeather and sea-LOD tier before the coast is built (`high` only changes the sea LOD presets; see [City sea LOD](./CITY_SEA.md#sea-lod-and-graphics-tiers-wr-3)).
- **Dolly:** `--dolly=M` moves the camera M metres forward (level) over the `--motion` frames, so a clip crosses LOD ring boundaries; the camera returns to the pose afterwards.
- **Bench:** `--bench=N` renders N frames of the first case's `open` shot (fresh, noon) after 30 warm-up frames and writes `bench.json`: mean and median wall time per frame, GPU time when the driver reports it (0 on GL Compatibility here) and the sea vertex count (every mesh under `Water`, MultiMesh instances counted).
- **Gust:** with `--motion`, the wind follows a deterministic envelope (two bursts of +0.4 and +0.24 at 2 s and 6 s) so the response of whitecaps, spray and surf to a gust can be recorded. Without `--motion`, a gust plate equals the base wind.

Build time is about 3 s; a plate takes a few seconds on an M-series GPU.

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_water_realism_v2,test_city_sea_lod
tools/godot_render.sh --script tools/water_sandbox/capture.gd -- --tag=check --shot=close --wind=fresh
```

The headless test builds the sandbox and checks every bay has sea offshore and land inshore, that large boulders are stamped into the ground, and that the runtime shore field and sea mesh exist. `test_city_sea_lod` also builds it and checks the ring/static cell ownership and the CPU sea height.

## Limits

- The ground uses the city ground shader, which paints land-use (grass, a cart-track stripe on the sand berm) from height alone; it is cosmetic in plates.
- Rocks smaller than 1.6 m are props only: the 2 m heightfield cannot hold them, so the water passes through them (local wave interaction around obstacles is WR-5).
- The sandbox has no player, swimmer, boats or underwater camera pass; `swim` is a camera at the surface only.
- It is a capture tool, not an interactive scene.
