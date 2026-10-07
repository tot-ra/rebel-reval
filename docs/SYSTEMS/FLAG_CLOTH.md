# Flag cloth

Status: implemented (task **R-1181**). Owner: dev. Scope: wind response of hoist-fixed flags (tower pennants, the town hall gable flag, merchant-cog masthead pennants) and the town hall wall banners. Sails, fishing nets and CPU cloth simulation are out of scope. Hoist-beam ropes and hooks share the same wind: see [Hoist ropes](HOIST_ROPE.md).

## What the player sees

Flags behave like light wool cloth in the shared world wind:

1. **Weathervane.** The cloth turns about its staff so the fly streams downwind, and hunts a few degrees either side (more in light air).
2. **Sag.** In light air gravity wins and the fly droops toward the staff; as the wind rises it lifts toward horizontal. It sags a little more in the lulls between gusts.
3. **Flutter.** A travelling wave runs from the hoist to the fly. The hoist stays pinned, the amplitude grows toward the free edge, the fly corners snap at a higher harmonic, and the wave gets faster and tighter in strong wind. The fly pulls toward the staff as the wave deepens, so the cloth does not visibly stretch.
4. **Shading.** Normals are rebuilt from the deformed surface, wave troughs take a little ambient occlusion, and sunlight shows through from behind (backlight).

Each flag gets its own phase and gust timing from its world position, so neighbouring towers never flap in sync. Town hall wall banners stay pinned at their rods and only sway at the hem.

## Runtime entry points

| Piece | Path |
| --- | --- |
| Flag shader | `scripts/map/view3d/map_view_flag_cloth.gdshader` (`MapViewMaterialShaders.FLAG_CLOTH_SHADER`) |
| Material cache | `MapViewMaterials.flag_cloth(srgb_vertex_color := false)` -> `map_view_wind_materials.gd` |
| Wall banner material | `MapViewMaterials.hanging_banner_cloth(albedo, srgb_vertex_color)` |
| Wind input | `MapViewMaterials.apply_world_wind(direction, strength)` updates `wind_direction` and `wind_strength` on every cached cloth material |
| Users | `_add_tower_pennant` (fortification builder), `_add_masthead_pennant` (merchant cog), `_add_banners` (town hall model) |

## Mesh contract

The flag shader poses the mesh entirely on the GPU, so the mesh must be authored flat:

- rest pose in local XY, hoist edge on `x = 0` (the staff axis, local Y);
- the fly runs toward `+X`, and `UV.x = x / fly length` (the shader derives the length from this, so one material serves cloths of any size);
- vertex `COLOR` carries the heraldry. Pass `srgb_vertex_color = true` when colours are authored in sRGB (the town hall cloth); `FactionHeraldry` meshes use the default.

`FactionHeraldry.pennant_mesh()` and the town hall `_banner_mesh(..., flying = true, ...)` follow this contract. Do not bake a wave or droop into a flying mesh; the shader adds both.

## Data and save/load

No content IDs and no persistent state. The look depends only on the world wind and render time.

## Verification

- Tests: `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_faction_heraldry,test_boat_float_3d,test_market_prototype_maps,test_map_view_material_resolution,test_merchant_boat_model`
- Visual: `tools/godot_render.sh --script tools/capture_flag_cloth.gd` writes `docs/reports/images/flag_cloth/flag_cloth_a.png` and `_b.png`: Danish pennants in light, moderate and strong wind plus the town hall flag, 0.4 s apart.

## Known limits

- The motion is analytic, not simulated: the cloth cannot wrap around its staff or collide with roofs.
- The weathervane turns the whole cloth about the staff, so a flag mounted against a wall can swing into it in a wind from that side. Wall-mounted cloth uses the hanging banner shader instead.
- Wind strength comes from the shared world value; there is no local sheltering behind buildings.
