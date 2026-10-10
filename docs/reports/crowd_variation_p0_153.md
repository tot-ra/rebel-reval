# Seeded crowd bodies - visual review (P0-153, task R-945)

Status: captured; named human sign-off **pending**. This report records an agent visual check only.

Plates (Kalev, `crowd_townsman_01`, `crowd_townsman_02`, `crowd_townswoman_01`, `crowd_townswoman_02`, left to right):

- Gameplay-camera angle: `docs/reports/images/characters/crowd_variation_iso_idle.png`
- Front lit close-up: `docs/reports/images/characters/crowd_variation_front_idle.png`

Capture: `tools/godot_render.sh --script tools/capture_character_closeup.gd -- --output-dir=... --scene=<variant .tscn>` once per body, then pasted side by side (PIL, half size). Plate validity: all ten frames have pixel extrema 0..204-255 and mean luma 17-61, so none is a black frame.

Limit: the closeup tool has a single stage light (warm sun, dim ambient). A separate day and night lighting pass was not captured because the task forbids changing the capture tool; the plates cover one lighting state.

## Per-body check (agent)

| Body | Reads as individual | Notes |
|------|---------------------|-------|
| `crowd_townsman_01` | accept | Shortest, blond cropped hair, mustard tunic, blue hose. **Amend candidate:** the saturated blue hose is the loudest dye in the set; confirm period plausibility of that blue. |
| `crowd_townsman_02` | accept | Tallest of the crowd, bald, green tunic. Differs from 01 in height, hair, garment colour. Green tunic is the same hue family as `crowd_townswoman_02`. |
| `crowd_townswoman_01` | accept | Red dress with pale apron and linen coif. Strongest silhouette difference. |
| `crowd_townswoman_02` | accept | Green long dress and coif. **Amend candidate:** near-identical garment hue to `crowd_townsman_02`; shift one seed or dye range if a reviewer sees them as a pair. |

Complexion: all four fall in a narrow light-to-medium range; a reviewer should decide whether that spans the intended Reval townsfolk range.

## Open items

- Named human accept/amend for dye palette and complexion range. On amend, change the seed or ranges in `tools/character_specs.py` and rebuild per `docs/CHARACTER_GENERATION.md` "Seeded crowd bodies".
- Day and night close-ups need a capture-tool lighting option (follow-up task).
