# Village and house windows

Status: implemented (task **R-1434**). Scope: seeded procedural windows on seamless-city houses built by `CityBuildingBuilder`, including exterior openings, interior relief and glazing. Out of scope: animated/interactive shutters, historical household wealth simulation, church/hall lancets, custom landmark models and older `MapView` facade assets.

## What the player sees

Timber **and** stone houses vary instead of repeating fresh white frames. A building-id-seeded visual tier selects a finish, glazing and frame style. It is an art tier, not a price, census assertion or saved household statistic. About one rural window in four can use a different construction within the same restrained palette.

| Style | Appearance |
|-------|------------|
| `plain` | Worn timber frame; poorer cottages can be unglazed |
| `shutters_open` | Separate plank leaves beside the opening, battens and iron straps |
| `shutters_closed` | Solid boarded leaves that hide the view from inside as well as outside |
| `slit` | Low smoke-house aperture with a partly slid board, no glazing |
| `surround` | Dressed stone jambs, lintel and sill |
| `leaded` | Small diamond panes with a fine, two-sided dark lead lattice |
| `panelled` | Raised panel-border shutter joinery, not pierced-heart decoration |

The palette prioritises bare/weathered wood, chalky whitewash, yellow ochre and red-brown earth washes. Muted green/blue-grey are reserved for the highest visual tier; they are not labelled cheap or assigned a historical local price. The window-only wood shader adds grain, exposed wood, worn pigment and rain streaks without a repeated image atlas. Planks also vary slightly in colour and depth. Legacy `platband` and `gable_cap` geometry remains callable for older tools/tests, but neither is automatically assigned to houses.

## Inside and outside are the same opening

Placement is calculated once. The builder subtracts each rectangular aperture from the existing exterior **and** interior wall triangles before adding the window mesh. This keeps filleted corners, gables, door openings and original wall UVs rather than building an unrelated second shell.

Enterable houses receive matching interior jambs, lintel returns and a broad sill projecting 18 cm past the inner wall. Glazing is one two-sided sheet near the exterior frame, not a black backing rectangle. The same exterior bars/shutters are visible through it from inside. Closed shutter boards have back faces and no through-cracks. Existing roof/interior cutaway behaviour remains in place.

| Glazing ID | Visual treatment | Base opacity |
|------------|------------------|--------------|
| `open` | No pane; genuinely open view | 0 |
| `horn` | Amber, highly cloudy horn-like substitute | 0.86 |
| `forest` | Greenish, uneven, cloudier glass | 0.56 |
| `clear` | Costlier, relatively clearer small panes, still uneven | 0.28 |

Opacity varies slightly across a sheet. These are artistic profiles, not measured transmission coefficients. They use alpha blending supported by GL Compatibility; there is no screen-space refraction, optical blur or real light transmission calculation. `horn` is translucent but not an accurate frosted-glass simulation. Clearer panes reveal more of the scene behind them. No shader needs an external image or generated GLB.

## Runtime entry points, data and persistence

- `scripts/city/city_windows.gd`: `look`, `placements`, `add_placed`, `add_window`, `add_interior`, shutter and lead-lattice relief.
- `scripts/city/city_window_openings.gd`: clips wall triangles, interpolating UVs/colours and retaining original face normals.
- `scripts/city/city_building_builder.gd`: mounts the shared placement in the shell; cuts walls after interior creation and before the existing cutaway split; caches `paint`, `iron` and `glass:<profile>` materials.
- `scripts/city/city_window_wood.gdshader` and `city_window_glass.gdshader`: procedural materials. Window wood does not alter the general `timber` material used elsewhere.
- Inputs: existing building `id`, `material`, `kind`, `wall_h`, `openings`, footprint, door gap and floor height. `openings: false` respects site-owned geometry.
- IDs and save/load: no content IDs, plan IDs, collision or saved data are changed. Appearance is reconstructed from the building ID on reload. Window placement preserves the previous wall RNG draw schedule, keeping roof/chimney random choices separate from ornament changes.
- Inputs: none added; keyboard/mouse/gamepad movement and entry remain unchanged. Windows are not climbable or interactable.

## Historical basis and confidence

- **High, general medieval practice:** wooden shutters on both glazed and unglazed openings; glass was costly and many domestic windows were unglazed. Linda Hall, [Historic window shutters](https://www.buildingconservation.com/articles/shutters/shutters.htm).
- **Medium as a northern-European material analogy, not a Reval 1343 claim:** bare timber, limewash and earth-pigment/red washes. Ben Kirk, [Paint Removal from Historic Timbers](https://www.buildingconservation.com/articles/paint-removal/paint-removal.htm). Much of that article's surviving evidence is later English work; it does not date every palette choice to 1343.
- **Low/local reconstruction:** exact pane distribution, horn substitutes, green/blue-grey finishes, panel borders and economic tier frequencies. These are explicitly art-direction approximations, not named historical facts. No modern opaque-white sash paint or late carved Russian nalichniki is selected automatically.

## Verify

```bash
# Use the installed Godot 4.7 binary if godot is not on PATH.
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_windows,test_city_window_openings
# Full regression suite:
godot --headless --path . --script tools/run_godot_tests.gd
# GPU captures, minimized/no-focus via the wrapper:
tools/godot_render.sh --script tools/capture_cottage_windows.gd
```

`tests/godot/test_city_windows.gd` covers seeded variety, relief and absence of opaque backing panes. `test_city_window_openings.gd` covers removed area on both faces, actual empty centres, interior sill depth, glass profiles/sidedness, closed shutter backs, low-wall/door clearance, deterministic integration, rotated-wall UV preservation, centre rays through actual plan-house panes and custom-site exclusion.

Captures under `build/windows/`:

- `cottage_windows.png`: seven exterior variants and glazing comparison targets.
- `interior_windows.png`: corresponding inward view and projecting sills.
- `plan_houses.png`: actual `CityPlan` timber/plank/stone house definitions, rebased into a review stage with original IDs/footprints. This is not a fully furnished live-city screenshot.

## Limits

- Custom site models, church/hall lancets and old `MapView` GLB facade windows remain unchanged; those use separate builders.
- Non-enterable buildings get exterior apertures/glazing but no new furnished room or interior sill.
- Visual holes do not change collision: a player cannot walk through a window.
- Alpha blending has normal transparent-surface sorting limitations. Horn-like panes tint/obscure but do not blur the outside view. Night lighting is unchanged.
- Window meshes have no separate distance LOD beyond existing chunk building range. They are merged per material, not separate nodes per window.
- Independent review is pending: the single permitted review-agent call failed without returning a review. Automated tests and captures are evidence, not second-reviewer approval.

### R-1434 verification result

- Focused windows + city plan/stream: **33 tests, 0 failures, 0 errors**; GDScript lint and `git diff --check` pass.
- Compatibility GPU capture: all three plates generated successfully with no shader errors.
- Full shared-working-tree harness: **2201 tests, 367 failures, 1172 errors**. This is not a green full-regression gate. Examples include missing generated burgher-house kits, map/source-reference compilation, changed canopy-wind contracts and a smithy test referring to removed `SMITHY_CHAIR_PROP_IDS`. Concurrent edits include `household_layout.gd`, `city_interiors.gd`, `map_view_canopy.gdshader`, `map_view_mesh_builder_prop_models.gd` and their tests; these are outside this change.
- Separate household regression: **10 tests, 1 failure** (`test_houses_have_hearth_bed_and_seats`, missing seat in house 87). The window change does not alter household placement or collision.
- Documentation reachability passes. The shared active-doc report already has unrelated broken links/anchors and is not a passing gate; isolated HEAD-plus-page comparison adds no issue rows. Its only page-derived inventory delta is two external research links. Do not regenerate the concurrently-edited report from this dirty tree.
- Task remains **in review**, not done, until a human or independent reviewer checks the images and implementation.
