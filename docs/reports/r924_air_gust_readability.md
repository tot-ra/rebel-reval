# R-924 Air Gust 3D readability review

**Review date:** 2026-09-26
**Task:** R-924 / second-reviewer Air Gust 3D readability
**Parent:** R-913 / R-722 follow-up (MapViewMagicVfx wind cone)
**Reviewer:** independent agent pass against the six R-913 studio plates
**Status:** **ACCEPT** - close R-913. Do not restyle the VFX.

## Decision

The six plates in `docs/reports/images/air_gust/` show a readable wind volume on the mid frames, a knockback slide away from Kalev for both the combat-room watchman and the Workers' District bandit, and no white-sheet or missing-actor frames. CombatKnockbackEffect was not in this review's allowlist and was not changed.

This is a second-reviewer plate check, not a human art-direction signature and not an in-map street acceptance. The capture stage is a flat studio floor (`tools/capture_air_gust.gd`), so cobble, foliage, and weather contrast remain unproven.

## Per-plate pair

| Check | Watchman pair | Bandit pair | Result |
|---|---|---|---|
| Readable wind volume on mid frames | Mid frame adds a translucent fan from Kalev toward the watchman, with scattered specks inside the wedge. Pale-pixel count vs before rises 189 -> 3082. | Same fan and specks toward the bandit. Pale-pixel count vs before rises 184 -> 2270. | **PASS** |
| Target slides away from Kalev | Watchman starts near Kalev's right, is farther right at mid, and farther still after. Spear and facing stay readable. before->after mean L1 12.09. | Bandit starts closer, is shoved right at mid, and continues right after. Sword stays in frame. before->after mean L1 12.33. | **PASS** |
| No white-sheet or missing-actor frames | Kalev and the watchman are present in before/mid/after. The wedge is a translucent overlay on the studio floor, not an opaque wash. Files are 1440x810, ~89-91 KiB. | Kalev and the bandit are present in all three frames. Same translucent overlay. | **PASS** |

## Explicit rejection checks

| Rejected form | Review result |
|---|---|
| Mid frame with no visible volume | **No rejection.** Both mid plates show a distinct lighter wedge plus specks. |
| Target stays planted | **No rejection.** Both targets move away from Kalev along the cast axis (logic +X). |
| White sheet or dropped actor | **No rejection.** Both actors stay fully visible through the overlay. |

## Non-blocking notes

1. Overlay captions use a light cream Label on the beige studio floor, so the title is low-contrast. That does not fail the cone/slide checks.
2. The after frames still show the wedge. That is acceptable for an after-slide still; it is not a fade-out proof.
3. Camera size is 7.0 (tighter than gameplay 33.75) so the cone is large in frame. Gameplay-scale in-map readability is a separate check.

## Verification

Commands run from the project root on 2026-09-26:

```sh
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_LOG_DIR=/tmp/rebel-reval-r924
./tools/run_godot_checked.sh --require-test-summary \
  r924-air-gust -- "$GODOT_BIN" --headless --path . \
  --script tools/run_godot_tests.gd -- \
  --filter=test_magic_air_gust,test_map_view_magic_vfx
# Godot 4.7.1: 2 file(s), 9 test(s), 0 failure(s), 0 error(s).
```

Plate inventory (all present, RGBA PNG, non-blank):

- [`combat_room_watchman_before.png`](images/air_gust/combat_room_watchman_before.png)
- [`combat_room_watchman_mid.png`](images/air_gust/combat_room_watchman_mid.png)
- [`combat_room_watchman_after.png`](images/air_gust/combat_room_watchman_after.png)
- [`workers_district_bandit_before.png`](images/air_gust/workers_district_bandit_before.png)
- [`workers_district_bandit_mid.png`](images/air_gust/workers_district_bandit_mid.png)
- [`workers_district_bandit_after.png`](images/air_gust/workers_district_bandit_after.png)

## Handoff

- R-913: move to done. Second-reviewer readability is recorded here.
- Optional follow-up (not required to close R-913): gameplay-camera in-map plates on a playable street so the pale wedge is judged against cobble and lighting, not only the studio floor.
