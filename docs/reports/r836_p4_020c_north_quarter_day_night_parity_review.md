# R-836 P4-020c North Quarter day/night parity review

**Task:** R-836 / P4-020c
**Parent:** R-245 / P4-020 North Quarter activation
**Review date:** 2026-09-01
**Map:** `north_quarter` / `reval_north`
**Decision:** **PENDING / BLOCKED - not accepted**

## Scope and decision boundary

This is an evidence-only review of the North Quarter matched day/night parity gate. It does not change `content/maps/north_quarter.rrmap`, runtime activation, transition release state, the activation ledger, or any image asset. The acceptance decision is binary: the gate is accepted only when a signed P4-023f packet covers the required North Quarter surfaces at the current map revision. Packet integrity, source proximity, and an `in_review` board status are not substitutes for that acceptance.

The current fail-closed state is preserved:

- `docs/data/p4_020_north_quarter_activation.json` remains `decision: "blocked"`.
- `parity_review.status` remains `"pending"`.
- `parity_review.day_capture` and `parity_review.night_capture` remain `null`.
- `active` and `implementation_delivered` remain `false`.
- P4-023f remains the owner of the signed day/night packet, environment review, population/activity evidence, seam evidence, and gameplay evidence.

## Acceptance result

| Required condition | Result | Review finding |
|---|---|---|
| Signed P4-023f North Quarter packet | **BLOCKED** | No signed P4-023f packet or reviewer sign-off/revision linkage was found. The available North Quarter manifest is `R-785 / P4-027d`, not P4-023f. |
| Matched gameplay-scale day/night views | **PARTIAL** | Two machine-valid North Quarter day/night pairs exist, but both are a single merchant-wall-tower presentation, not district-wide coverage. |
| Current map/revision identity | **BLOCKED** | The R-785 manifest records compiled fingerprint `da6bfe9e553638388fd0bc578eca68f236574ad91528f1cf68602f942174211f`, but does not establish a signed P4-023f source-to-packet revision. The shared worktree is dirty; current raw RRMap SHA-256 is `69d254aef8d10ab4bafabdff5f69f374bac5991376638ff05f102998a65c56b3`, while the `HEAD` blob is `f9adde40f18ba5e9c2b320db31ed5af1072c695b`. |
| Coastal Gate coverage | **BLOCKED** | No accepted pair identifies `coast_gate_arch`, `coast_gate_west_tower`, and `coast_gate_east_tower` in a gate approach/opening review. |
| Harbourward relief and runoff | **BLOCKED** | Structural source IDs exist, but no accepted pair visually reviews `r454.north.east_harbour_fall` and the three runoff cues `decal.coastal_gate_runoff`, `decal.coastal_gate_sill_mud`, and `decal.coastal_gate_outer_runoff` in the North Quarter packet. |
| Material variety and district identity | **BLOCKED** | Source styles and property rows exist, but no district-scale, material-readable matched pair demonstrates timber/plank/plaster/limestone, tile/shingle/thatch, route surfaces, and non-repeated frontage together. |
| Routes, population/activity, seams, and gameplay evidence | **BLOCKED** | These remain explicitly open in the P4-023 environment acceptance handoff. No supplementary image is promoted to replace those gates. |

**Binary disposition:** `accepted = false`; `pending = true`. R-836 does not authorize parity approval or activation-ledger updates.

## Available evidence inventory

### R-785 Rentenitorn packet: machine-valid but out of scope for P4-023f

Manifest: [`images/rentenitorn/capture_manifest.json`](images/rentenitorn/capture_manifest.json)

The manifest declares task `R-785 / P4-027d`, renderer `gl_compatibility`, OpenGL 3 driver `opengl3`, viewport `1280x720`, orthographic gameplay size `33.75`, pitch `-30`, yaw `45`, and distance `90`. Its `north_quarter` entry is inactive and records compiled fingerprint `da6bfe9e553638388fd0bc578eca68f236574ad91528f1cf68602f942174211f`. This is useful reproducibility evidence, but it is not a P4-023f signature or current-revision acceptance record.

The four North Quarter outputs are present, decode as `RGBA 1280x720`, are non-blank, and have matched day/night framing keys:

| View | Day output and SHA-256 | Night output and SHA-256 | Framing key | Stable-ID coverage |
|---|---|---|---|---|
| Exterior tower approach | [`north_quarter_merchant_wall_tower_northwest_day.png`](images/rentenitorn/north_quarter_merchant_wall_tower_northwest_day.png) `f4537b0532702d832cc49a5fe59522e1482d8dc9b8eac7ef8cc3dc47e2ef0231` | [`north_quarter_merchant_wall_tower_northwest_night.png`](images/rentenitorn/north_quarter_merchant_wall_tower_northwest_night.png) `ec8d0cc4dd6f69ba66ab4fae1b39b4441a53902bf0181ff2a77f1cf41144b562` | `north_quarter_merchant_wall_tower_northwest|11.000|0.800|13.500|33.750` | `merchant_wall_tower_northwest` |
| Exterior south door and return spawn | [`north_quarter_merchant_wall_tower_northwest_door_day.png`](images/rentenitorn/north_quarter_merchant_wall_tower_northwest_door_day.png) `d30fb212cc57f015423641a8ed640634f5d5b86fb3d25e61aa19bf11f6d1aee2` | [`north_quarter_merchant_wall_tower_northwest_door_night.png`](images/rentenitorn/north_quarter_merchant_wall_tower_northwest_door_night.png) `144309c46569a3963248df459f068429d8f035f9f8d6544207ac0f4bcab49c3e` | `north_quarter_merchant_wall_tower_northwest_door|11.000|0.800|15.000|33.750` | `merchant_wall_tower_northwest`, `rentenitorn_enter`, `merchant_wall_tower_northwest_return` |

Decoded pixel comparisons confirm that these are real day/night variants, not duplicate files:

- Exterior tower approach: `99.6981%` of pixels differ; mean absolute RGB difference `92.7283`.
- Exterior door/return view: `99.6478%` of pixels differ; mean absolute RGB difference `92.2698`.

These results establish pair integrity only. The stable-ID set is tower/door focused and does not cover the Coastal Gate, district routes, harbourward relief, material families, or the full North Quarter frontage.

The same manifest also contains `rentenitorn_interior_day.png` and `rentenitorn_interior_night.png`. Those plates belong to `rentenitorn_interior`, not `north_quarter`, and are excluded from this review rather than copied into the North Quarter packet.

### Elevation directory: supplementary images without an acceptance manifest

The following files exist under [`images/elevation/`](images/elevation/), but there is no `capture_manifest.json` in that directory:

| Pair | Files | Dimensions and limitation |
|---|---|---|
| Player-eye | [`reval_harbor_north_player_eye_day.png`](images/elevation/reval_harbor_north_player_eye_day.png) `284320aed9211d2faa38be1529b367f285b3520a993b3df3d1e8ba780755125b` and [`reval_harbor_north_player_eye_night.png`](images/elevation/reval_harbor_north_player_eye_night.png) `768df8a11ce657363fe7e3f345bb96556633718de612d5bc637008e14c2276bf` | Both `RGB 1600x900`; map label is `reval_harbor_north`, not `north_quarter`, and no P4-023f revision/sign-off metadata is attached. |
| Top-down | [`reval_harbor_north_top_down_day.png`](images/elevation/reval_harbor_north_top_down_day.png) `f5b59eff0cc35f97c14185bf8bd1d65f525624cf0d67a20eaca963c97ad7a93d` and [`reval_harbor_north_top_down_night.png`](images/elevation/reval_harbor_north_top_down_night.png) `3f13b54c83d46178bb17f64e38bcaf1c1e2478ab64c86634e9add09c8cc9014d` | Both `RGB 1600x900`; top-down/debug framing is not an accepted gameplay-scale replacement, and the map label still does not identify North Quarter. |

The two Harbour pairs are also visibly distinct by decoded pixels: player-eye `100%` changed pixels / mean absolute difference `112.1657`; top-down `100%` / `96.8392`. Distinct pixels do not repair their wrong map scope or missing packet linkage.

## Required replacement packet

P4-023f must provide a single signed North Quarter packet with all of the following:

1. A manifest naming `map_id: north_quarter`, `scene_id: reval_north`, the raw authored-map revision, the compiled semantic fingerprint, renderer, viewport, camera pose, and capture command.
2. Matched day/night gameplay-scale pairs at identical framing and dimensions for at least:
   - Coastal Gate approach/opening, identifying `coast_gate_arch`, `coast_gate_west_tower`, and `coast_gate_east_tower`.
   - The Pikk-to-harbour route and harbourward relief, identifying `pikk_street_spine`, `harbor_approach`, `to_reval_harbor`, `r454.north.east_harbour_fall`, and the relevant runoff cues.
   - `merchant_court` and representative property rows showing material and roof variation without a blanket cobblestone field.
   - A district-scale route/readability view that demonstrates North Quarter identity rather than an isolated Rentenitorn tower.
3. Stable-ID annotations or equivalent reviewer-observation records tied to the visible surfaces. Source proximity alone must not be promoted to a visual observation.
4. Named historical/canon and art reviewers with recorded verdicts for the 1343 Coastal Gate, relief/readability, materials, and district silhouette.
5. Separate evidence or explicit accepted handoffs for population/activity profiles, reciprocal monastery-wall seams, and gameplay loop/interaction coverage, as required by [`p4_023_north_quarter_environment_acceptance.md`](p4_023_north_quarter_environment_acceptance.md).

Until that packet is signed and linked to the current map revision, `parity_review` must remain pending and the activation ledger must remain blocked.

## Verification

The following scoped checks were rerun for this review:

```text
python3 tools/verify_north_quarter_activation.py
# PASS: fail-closed activation ledger is internally consistent; decision remains blocked

python3 -m unittest tests.python.test_verify_north_quarter_activation -v
# PASS: 4 tests, OK

export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
tools/run_godot_checked.sh --require-test-summary r836-north-quarter-prototype \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_north_quarter_prototype_map
# PASS: 1 file, 10 tests, 0 failures, 0 errors
```

The visual audit independently checked all eight listed PNGs for existence, decode, dimensions, non-blank payload, and SHA-256. Manifest-backed framing was checked for the two R-785 North Quarter pairs; decoded-pixel distinctness was checked for all four available day/night pairs. The R-785 manifest and all North Quarter plate paths were inspected directly. No visual acceptance claim is made for the supplementary Harbour images.

## Sources

- [`../data/p4_020_north_quarter_activation.json`](../data/p4_020_north_quarter_activation.json)
- [`p4_023_north_quarter_environment_acceptance.md`](p4_023_north_quarter_environment_acceptance.md)
- [`r834_p4_020a_upstream_dependency_reconciliation.md`](r834_p4_020a_upstream_dependency_reconciliation.md)
- [`r835_p4_020b_north_quarter_elevation_parser_gate.md`](r835_p4_020b_north_quarter_elevation_parser_gate.md)
- [`images/rentenitorn/capture_manifest.json`](images/rentenitorn/capture_manifest.json)
- [`images/rentenitorn/`](images/rentenitorn/)
- [`images/elevation/`](images/elevation/)
- [`../../content/maps/north_quarter.rrmap`](../../content/maps/north_quarter.rrmap)
- [`../../tests/godot/test_north_quarter_prototype_map.gd`](../../tests/godot/test_north_quarter_prototype_map.gd)
- [`../../tools/verify_north_quarter_activation.py`](../../tools/verify_north_quarter_activation.py)

**Final status:** **R-836 review complete; parity acceptance remains PENDING/BLOCKED.** No activation or implementation change is authorized by this report.
