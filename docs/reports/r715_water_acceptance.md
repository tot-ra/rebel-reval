# R-756 water acceptance packet

- Task: R-756
- Parent: R-715, realistic reflective water rollout
- Recorded: 2026-08-27
- Status: **BLOCKED - real-renderer capture and human visual review pending**
- Capture identity: `r715-water-acceptance-v1`

## Evidence boundary

This packet is fail-closed. It records the complete water-bearing map matrix and the exact fixed-setting capture contract, but it does not promote structural inventory into visual acceptance. No placeholder image is treated as a capture. The manifest keeps every unrun plate at `status: blocked`, with an explicit `not captured` annotation and blockers.

The capture runner is intentionally one-plate-per-process. It rejects the headless dummy renderer before creating output and requires a display-capable Metal run. A successful renderer run promotes only the selected plate to `captured_pending_review`; visual checks remain `not_reviewed` until a human review records them. The runner cannot self-approve a plate.

## Fixed capture settings

| Field | Contract |
|---|---|
| Capture identity | `r715-water-acceptance-v1` |
| Engine | Godot 4.7 |
| Renderer | Metal required; headless readback is rejected |
| Viewport | `1280x720` |
| Quality | `recommended` |
| Process policy | one process per plate |
| Output | `docs/reports/images/r715_water/<map>_<scenario>_<time>.png` |
| Integrity | PNG decode, exact dimensions, non-blank payload, SHA-256 |
| Review | human visual review required before acceptance |

## Coverage matrix

The manifest contains 13 water-bearing map definitions x 5 weather/presentation scenarios x 2 times of day = **130 unique plate IDs**. Each plate records map ID, closed water terrain IDs, water context, scenario, weather, day/night, quality, renderer, viewport, output path, status, checksum, six visual checks, annotation, and blockers.

| Map ID | Water terrain IDs | Water context | Plates |
|---|---|---|---:|
| `smithy_courtyard` | `water` | enclosed water | 10 |
| `lower_town_slice` | `water` | enclosed water, shoreline | 10 |
| `south_quarter` | `water` | enclosed water, shoreline | 10 |
| `viru_gate_foreland` | `river_water` | river, shoreline | 10 |
| `reval_harbor_north` | `shallow_water`, `deep_water` | harbour, shoreline, open coast | 10 |
| `reval_harbor_east` | `shallow_water`, `deep_water` | harbour, shoreline, open coast | 10 |
| `prototype.paldiski_coastal_outpost` | `shallow_water`, `deep_water` | open coast, shoreline | 10 |
| `prototype.sacred_grove` | `shallow_water` | shoreline, enclosed water | 10 |
| `prototype.saaremaa` | `shallow_water`, `deep_water` | open coast, shoreline | 10 |
| `prototype.swedish_arrival` | `shallow_water`, `deep_water` | open coast, shoreline | 10 |
| `world.sacred_grove` | `shallow_water` | shoreline, enclosed water | 10 |
| `world.padise` | `water`, `river_water`, `shallow_water` | river, shoreline, enclosed water | 10 |
| `world.saaremaa` | `shallow_water`, `deep_water` | open coast, shoreline | 10 |

Every map receives these scenario/time pairs:

- `clear`: day and night
- `overcast`: day and night
- `rain`: day and night
- `storm`: day and night
- `post_rain`: day and night, representing rain-to-clear presentation with retained wetness

## Required visual review rubric

Each plate must receive an explicit `pass`, `fail`, or `blocked` result for all six checks. Until a real-renderer image exists and a reviewer inspects it, all six remain `blocked`:

1. **Reflection continuity** - screen/sky reflection remains coherent across the water surface and adjacent map framing.
2. **Wave readability** - calm, river, shallow, deep, rain, and storm wave patterns read at gameplay scale without noisy or flat output.
3. **Shoreline grounding** - shoreline retreat, foam, rocks, and bank contact do not float, z-fight, or create an unintended gameplay boundary.
4. **Underwater depth** - shallow/deep optical response and visible bed depth remain distinct without exposing a broken fallback.
5. **Night readability** - moon/stars/celestial highlights and water silhouettes remain readable without a crushed or detached surface.
6. **Parity** - view construction preserves authored terrain fingerprints, stable IDs, collision/navigation, and map-specific exceptions.

## External ownership handoffs

- **R-529** owns the pre-existing Monastery east-ditch regression. It is not included in this packet's map matrix and cannot be waived by a water capture.
- **R-713** owns unified sky/weather continuity. This packet consumes the shared presentation contract but does not duplicate or accept the sky/weather evidence.
- **R-755** owns renderer budget and hardware evidence. This packet does not infer performance acceptance from the 130-plate manifest.

## Artifacts and commands

| Artifact | Purpose |
|---|---|
| [`capture_manifest.json`](images/r715_water/capture_manifest.json) | 130 stable plate identities, metadata, checks, checksums, statuses, and blockers |
| [`tools/capture_r715_water_acceptance.gd`](../../tools/capture_r715_water_acceptance.gd) | one-plate real-renderer capture with fixed settings and fail-closed guards |
| [`tests/godot/test_r715_water_acceptance_packet.gd`](../../tests/godot/test_r715_water_acceptance_packet.gd) | structural matrix, metadata, uniqueness, handoff, and fail-closed source contract |
| [`r715_water_rollout_inventory.md`](r715_water_rollout_inventory.md) | upstream 13-definition rollout inventory and ownership boundaries |
| [`r713_sky_weather_acceptance.md`](r713_sky_weather_acceptance.md) | external R-713 weather evidence and blocker boundary |

Run one selected real-renderer plate:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method mobile --rendering-driver metal \
  --script tools/capture_r715_water_acceptance.gd -- \
  --map=reval_harbor_north --scenario=storm --time=night
```

Run the structural contract:

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_r715_water_acceptance_packet
```

A complete packet may move beyond `BLOCKED` only after all required plates are captured, checksums and dimensions verify, visual rubric results are recorded, and human review is documented. This task does not claim that state.
