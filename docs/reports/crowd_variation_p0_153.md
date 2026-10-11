# Seeded crowd bodies - visual review (P0-153, task R-945)

Status: captured; named human sign-off **pending**. Day/night capture tooling and recapture implemented in **R-1674**. This report records an agent review decision only, not historical or human art approval.

## Current plates (R-1674)

Left to right: Kalev, `crowd_townsman_01`, `crowd_townsman_02`,
`crowd_townswoman_01`, `crowd_townswoman_02`. These are the current realistic
shared-rig scenes, not the retired procedural bodies. Seeds and production assets
are unchanged.

| Lighting | Gameplay-camera angle (portrait distance) | Front close-up |
|---|---|---|
| Day | [Day isometric](images/characters/crowd_variation_day_iso_idle.png) | [Day front](images/characters/crowd_variation_day_front_idle.png) |
| Night | [Night isometric](images/characters/crowd_variation_night_iso_idle.png) | [Night front](images/characters/crowd_variation_night_front_idle.png) |

The original single-lighting evidence remains available:
[isometric](images/characters/crowd_variation_iso_idle.png),
[front](images/characters/crowd_variation_front_idle.png).

Capture each body with:

```bash
tools/godot_render.sh --script tools/capture_character_closeup.gd -- \
  --scene=res://assets/characters/variants/crowd_townsman_01.tscn \
  --lighting=night --output-dir=res://build/r1674/night/crowd_townsman_01
```

Repeat with `day`, both townsmen and both townswomen; Kalev's scene is
`res://assets/characters/kalev/kalev.tscn`. Each run emits seven 720x900 poses.
The committed sheets use `iso_idle` and `front_idle`, resized with Pillow LANCZOS
to 360x450, pasted in the above order with labelled headers (1800x486 sheet).
The remaining source poses and run logs are local evidence under `build/r1674/`.
Tool contract and limits: [Character generation](../CHARACTER_GENERATION.md#character-close-up-review-lighting-r-1674).

## Plate validity and verification

Captured on Godot 4.7.1, Metal/Mobile through the minimized render wrapper.
All ten runs exited 0 and wrote all seven poses. No script or shader errors.
Luma below is measured on the original 720x900 RGB frames converted to Pillow `L`,
not on the labelled/resized sheets:

| Lighting / view | Mean luma range across five bodies | Peak luma range |
|---|---:|---:|
| Day isometric | 48.984-53.177 | 159-231 |
| Day front | 20.941-25.814 | 186-232 |
| Night isometric | 15.925-17.789 | 70-165 |
| Night front | 8.788-11.368 | 88-165 |

None of the twenty review frames is black. The cooler, dimmer night preset is
intentionally less legible than day; it is a controlled audit light, not proof
of live city night visibility.

- `--filter=test_capture_character_closeup`: 4 tests, 0 failures/errors.
- `python3 -m gdtoolkit.linter tools/capture_character_closeup.gd tests/godot/test_capture_character_closeup.gd`: passes.
- Invalid `--lighting=dusk`: exit 1, zero captures.
- Before/after omitted-argument capture: six of seven PNGs byte-identical;
  `front_idle` has mean absolute RGB differences of only 0.0064/0.0046/0.0042
  on the 0-255 scale. Repeating the unchanged new script also produces that
  idle-frame variation. Exact GPU PNG identity is therefore not guaranteed;
  the default parameters, poses, output paths and camera are unchanged and
  regression-tested. Explicit `day` uses the same stage as omission.

## Per-body decisions (agent)

| Body | Decision | Notes |
|------|----------|-------|
| `crowd_townsman_01` | retain seed and dye | Blue hose remains the strongest cool garment colour; the realistic spec uses muted `woad_blue` (0.27, 0.35, 0.46). No palette rebuild justified by the former procedural plate alone. Named historical/art approval is still required. |
| `crowd_townsman_02` | retain seed and dye | Bald head, male tunic and different stature distinguish it from the green-dressed woman. Shared green is not itself a clone defect. |
| `crowd_townswoman_01` | retain seed and dye | Red dress, pale apron and head covering distinguish the silhouette. |
| `crowd_townswoman_02` | retain seed and dye | Keep the shared green family with townsman 02; long dress and head covering distinguish the body. No seed shift or production-asset change in this tooling task. |

Complexion remains a narrow light-to-medium range. This task does not establish
historical representativeness or authorize rebuilding skin/garment assets.

## Open items

- Parent **R-945** retains named human accept/amend ownership for the current
  day/night plates, dye palette and complexion range. It remains `in_review`.
- If the reviewer requests an amendment, create a production-art task naming
  the exact seed/spec and assets, use the current realistic pipeline in
  [Character generation](../CHARACTER_GENERATION.md), and recapture both lights.
