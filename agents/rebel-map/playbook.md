# Map playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Map role.

## Role-specific lessons
- RRMap `stroke` thickness grows from the start point in +x/+y; it is not centred. Author river and lane strokes from their top-left edge. Polylines are strictly orthogonal; represent angled approaches as stepped axis-aligned segments.
- Express outdoor buildings as roofed `house` records. Reserve roofless `kind=wall` for burnt-out shells and boundary walls. `kind=interior_wall` renders as a stockade.
- A new `view_landmark` kind needs `MapDefinition.VIEW_LANDMARK_KINDS`, the `_compile_landmark` field copy, and `LANDMARK_OVERRIDE_KEYS`. A new typed style key also needs compiler build and expand-geometry field copies.
- RRMap parser support files live under `scripts/map/rrmap/`. The compiler expands long interior walls into `wall.../segment.000` IDs. Source stable IDs are the second token on `building` / `landmark` lines.
- In transitions, `destination_spawn_id` names the target map's entry marker and `spawn_id` names the local arrival marker. Reciprocal-route tests must assert both.
- `exclude` rects create blocked cells. Restored anchors must sit outside blocking terrain or they trigger `MAP_ANCHOR_BLOCKED`.
- New Game places the player via DoorNavigator spawn `smithy_start`, not `definition.player_spawn`. Keep `transition smithy_start_spawn` on the same wake cell as `ap.sleep.wake`.
- An NPC "standing on the smithy anvil" is usually an authored anvil-bound activity (`ap.visitor.inspect` / `ap.forge.anvil`), not a stray spawn. Spoken "кавальня" usually means outdoor `courtyard_anvil`.
- Retiring a stable outdoor prop ID requires regenerating `lower_town_slice.parity.json` in the same change.
- Headless dummy rendering cannot read a SubViewport texture. Use Metal. Prop close-ups must zero `build_prop` world position. Day/night calibration needs one Godot process per plate.
- When a close-up needs different framing, re-aim the shipped camera along its own `basis.z`. An orthographic isometric camera offset in world XZ slides into sky.
- Keep RRMap Editor Edit map and Align maps as separate modes. Prop kinds should be a filtered OptionButton over `MapTypes.ALL_PROP_KINDS`.
- Focused Lower Town contracts should inspect compiled `MapDefinition` records. RRMap prop footprints are optional. Decals are view-only and must not alter terrain fingerprints.
- Edge greenery can sit against wall or gate-house footprints. Do not require a bush center to be walkable; prove non-blocking behavior through route reachability.
- Before asserting an rrmap style name at runtime, inspect compiler output: resolved building dictionaries can retain `primitive` while dropping the authored `style`.
- Frontage width: `north` / `south` use `w`, `east` / `west` use `h`.
- `test_editor_portfolio_contains_accepted_campaign_greyboxes` asserts `definition.size_cells` against the `map` header. After resizing a campaign greybox rrmap, update that Vector2i in the same change.
- Outdoor night crushed to black after ADR 0018 is usually ambient/fill and night multipliers, not the 20% post-grade luminance proxy alone.
- The lightweight Godot `test_case.gd` harness does not provide `assert_almost_eq`. Use an explicit `absf` tolerance.
- When carving a narrow smithy commit, reset `kalev_smithy.rrmap`, `kalev_smithy_domestic_life.json`, and `content/routines/kalev_smithy.json` together to a matched baseline.
