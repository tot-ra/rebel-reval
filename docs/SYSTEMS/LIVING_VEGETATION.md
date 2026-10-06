# Living vegetation

Status: implemented (task **R-1187**). Scope: tree crowns in the 3D view follow the campaign calendar, react to rain and wind, and respond to melee swings. Presentation only: nothing here changes combat, collision, navigation, or saved state. Out of scope: felling or damaging trees, persistent leaf litter on the ground, snow on branches, seasonal bushes, grass, and crops, and blossom.

Reference bar: trees that feel alive in the way Witcher 3 and RDR2 trees do. The crown changes with the month, and a blow to the trunk knocks leaves loose.

## What the player sees

- **Seasons.** Deciduous crowns follow northern Estonian (Tallinn) phenology as a function of the in-game date: bare in winter. Bud-burst starts in late April with sparse, small, light yellow-green leaves. Crowns are full from June to August. Autumn colouring runs from mid September, with per-species palettes (birch and aspen gold, maple and rowan red, oak brown), several hues per crown, and the oldest leaves turning brown. The crowns are bare by early November. Early leafers (birch, willow, aspen, alder, orchard trees) open before late leafers (oak, ash, linden, elm, maple). Conifers keep their needles and turn duller and bluer in deep winter. On the slice's opening date, 21 April 1343, birches show about 28% of their leaves, small and fresh, and oaks show only their first buds.
- **Fruit** appears only in season: cherries in July, plums in August and September, apples and pears from August to October, rowan and hawthorn berries from August to November, and sloes from September to November.
- **Rain** darkens leaves and bark and makes them glossy. Leaves get wet from active rain at once, not only when puddles form.
- **Wind** moves crowns at two frequencies: whole limbs heave in gusts, rigid from the petiole, while leaf tips flutter.
- **Melee swings.** When a landed swing (hit or miss) reaches a tree in front of Kalev, that crown shakes away from the blow and rings down over about 1.8 s, and a burst of leaves in the current season's colours tumbles to the ground. Heavy blows shake harder and drop more. Autumn crowns are the loosest. Conifers drop a few needles, and bare trees drop nothing.
- **Ambient leaf fall.** Leaves drift down around the player where trees stand nearby: heavily in October, a few during storms in any season with leaves, and none in open streets or bare winter woods. The wind carries them sideways.

## Runtime entry points

| Piece | File |
|---|---|
| Seasonal model (pure, deterministic) | [`vegetation_phenology.gd`](../../scripts/map/view3d/vegetation_phenology.gd) (`VegetationPhenology.state_for`, `falling_leaf_colors`, `hit_leaf_count`) |
| Crown shader (season, autumn hue, crown AO, wetness, two-frequency wind, hit shake) | [`map_view_canopy.gdshader`](../../scripts/map/view3d/map_view_canopy.gdshader) |
| Per-species crown materials, season and wetness fan-out | [`map_view_wind_materials.gd`](../../scripts/map/view3d/map_view_wind_materials.gd) (`canopy_for_species`, `apply_vegetation_season`, `apply_vegetation_wetness`) |
| Seasonal fruit, wet bark | [`map_view_prop_materials.gd`](../../scripts/map/view3d/map_view_prop_materials.gd) (`tree_fruit_for_species`, `apply_fruit_season`, `apply_bark_wetness`) |
| Leaf mesh contract | [`map_view_leaf_geometry.gd`](../../scripts/map/view3d/map_view_leaf_geometry.gd), [`map_view_tree_meshes.gd`](../../scripts/map/view3d/map_view_tree_meshes.gd) |
| Strike query, crown shake, leaf bursts, ambient leaves | [`tree_leaf_fall_3d.gd`](../../scripts/map/view3d/tree_leaf_fall_3d.gd) (`TreeLeafFall3D`, child `TreeLeafFall` of every `MapView3D`) |
| Wiring | `MapView3D.set_calendar_date` pushes the season, `MapView3D.strike_vegetation` resolves a swing, and `MapView3D._process` drives ambient leaves. `MapViewMaterials.apply_weather_presentation` pushes wetness. `MapViewRuntimeActors._on_player_melee_attack_resolved` calls `strike_vegetation` with `Player.facing_direction()` and the `AttackProfile` reach, cone, and `is_heavy` flag |

## Data contracts

- **Leaf vertices** (tree canopy meshes only): `UV2.x = 1` tags a leaf. `CUSTOM0 = (petiole xyz, seed)` with seed in 0..1. `COLOR.a` holds the baked crown self-occlusion (0.48 inside the crown, 1 at the outer shell). The shader collapses a leaf to its petiole when `seed > leaf_density` and scales it by `leaf_scale`. Leaves with high seeds colour first and fall first, so the last leaves on an autumn tree are the greenest. Bushes and legacy canopies have no tag and keep the old height-weighted sway and summer look.
- **Season uniforms** live on one material per species (`canopy_species:<species>`), so trees still draw as one MultiMesh per species and add no draw calls. Streamed chunks and materials created after a cache reset pick up the last pushed date.
- **Hit shake**: scatter tree crowns are MultiMeshes with `use_custom_data`. `INSTANCE_CUSTOM.xy` holds the crown-top offset in world metres and `.z` the extra leaf flutter. `TreeLeafFall3D` writes these only for struck trees and zeroes them after the shake.
- **Strikeable trees**: `TreeLeafFall3D.tag_canopy` puts the canopy MultiMesh in group `tree_canopy_multimesh` and stores its species and instance transforms as node meta. MultiMesh buffers are GPU-side, so they are not read back. Authored single trees (`MeshInstance3D` "Canopy" in group `tree_canopy_mesh`) drop leaves but do not shake.
- **Determinism**: the season is a pure function of `GameCalendar.day_of_year` (Julian leap years included). There is no RNG and no persisted state, so save/load, phase changes, and seam crossings always agree with the HUD date.

## Verify

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_vegetation_phenology,test_tree_leaf_fall,test_vegetation_realism,test_map_view_tree_species
```

- [`test_vegetation_phenology.gd`](../../tests/godot/test_vegetation_phenology.gd) checks winter bareness, the 21 April bud-burst range, full summer crowns, October colouring and shedding, evergreen conifers, continuity and determinism, Julian leap years, and hit strength.
- [`test_tree_leaf_fall.gd`](../../tests/godot/test_tree_leaf_fall.gd) checks the strike query (nearest tree in front, ignoring trees behind or out of reach), shake ring-down, bursts only from leafed trees, ambient rate against season, wind, and tree count, season delivery to materials and fruit, and the leaf `CUSTOM0` and occlusion contract.

## Limits

- No GPU capture plates are attached yet. Visual tuning (autumn saturation, bud-burst look, burst size) needs a rendered review with `tools/godot_render.sh`.
- Fallen leaves vanish when they land. There is no persistent ground litter, and grass and bushes do not change with the season.
- Only the player's swings strike trees. NPC melee, magic blasts, and projectiles do not.
- When two hosted views overlap at a seam, each runs its own ambient emitter, which can double the leaf fall right at the seam.
- Late-April leaf density is a design choice for the slice's spring look. Real Tallinn birches usually break bud a week or two later.
