extends "res://tests/godot/test_case.gd"

## R-1200: hoist ropes with a forged hook swing in the world wind instead of
## standing as rigid baked cylinders.

const TownHallModel := preload("res://scripts/map/view3d/map_view_town_hall_model.gd")
const WindMaterials := preload("res://scripts/map/view3d/map_view_wind_materials.gd")
const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")


func test_mesh_follows_shader_contract() -> void:
	var mesh := MapViewHoistRope.build_mesh(3.0)
	assert_eq(mesh.get_surface_count(), 2, "rope surface + hook surface")
	var rope := mesh.surface_get_arrays(0)
	var rope_uv2: PackedVector2Array = rope[Mesh.ARRAY_TEX_UV2]
	var rope_vertices: PackedVector3Array = rope[Mesh.ARRAY_VERTEX]
	var top := -INF
	var bottom := INF
	for i in rope_vertices.size():
		top = maxf(top, rope_vertices[i].y)
		bottom = minf(bottom, rope_vertices[i].y)
		assert_almost_eq(rope_uv2[i].x, 0.0, 0.001, "rope vertices are not hook vertices")
		assert_almost_eq(rope_uv2[i].y, 3.0, 0.001, "UV2.y carries the rope length")
	assert_almost_eq(top, 0.0, 0.001, "rope hangs from the anchor at the origin")
	assert_almost_eq(bottom, -3.0, 0.02, "rope reaches the hook eye")
	var hook := mesh.surface_get_arrays(1)
	var hook_uv2: PackedVector2Array = hook[Mesh.ARRAY_TEX_UV2]
	var hook_vertices: PackedVector3Array = hook[Mesh.ARRAY_VERTEX]
	assert_true(hook_vertices.size() > 0, "hook geometry exists")
	for i in hook_vertices.size():
		assert_almost_eq(hook_uv2[i].x, 1.0, 0.001, "hook vertices are flagged for rigid follow")
		assert_true(hook_vertices[i].y < -2.95, "hook hangs below the rope end")
	assert_true(MapViewHoistRope.build_mesh(3.0) == mesh, "meshes are cached per length")


func test_rope_materials_follow_world_wind() -> void:
	var previous_direction := WindMaterials.world_wind_direction()
	var previous_strength := WindMaterials.world_wind_strength()
	var hemp := MapViewMaterials.hoist_rope_hemp()
	var iron := MapViewMaterials.hoist_rope_iron()
	assert_true(WindMaterials.wind_materials().has(hemp))
	assert_true(WindMaterials.wind_materials().has(iron))
	MapViewMaterials.apply_world_wind(Vector2(0.0, 1.0), 0.8)
	assert_almost_eq(float(hemp.get_shader_parameter("wind_strength")), 0.8, 0.0001)
	assert_almost_eq(float(iron.get_shader_parameter("wind_strength")), 0.8, 0.0001)
	assert_eq(hemp.get_shader_parameter("wind_direction"), Vector2(0.0, 1.0))
	MapViewMaterials.apply_world_wind(previous_direction, previous_strength)
	var rope := MapViewHoistRope.create(2.0)
	assert_eq(rope.get_surface_override_material(0), hemp)
	assert_eq(rope.get_surface_override_material(1), iron)
	assert_true(rope.extra_cull_margin >= 0.5, "a swung hook must not be culled")
	rope.free()


func test_merchant_stone_hangs_live_rope_at_kit_markers() -> void:
	var building := {
		"id": &"merchant_stone_hoist_rope",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"house_tier": &"merchant_stone",
		"footprint": Rect2(0.0, 0.0, 9.0 * 32.0, 10.0 * 32.0),
		"wall_height": 144.0,
		"door_side": &"south",
	}
	var node := MapViewMeshBuilder.build_building(building, MapTypes.DEFAULT_CELL_SIZE)
	var model := node.get_node_or_null("ProductionMerchantStone") as Node3D
	assert_true(model != null, "merchant_stone uses the production GLB")
	var rope := node.get_node_or_null(MapViewHoistRope.NODE_NAME) as MeshInstance3D
	assert_true(rope != null, "the kit hoist gets a live rope")
	if model != null:
		assert_true(
			model.find_child("*Rope", true, false) == null,
			"no baked rope mesh remains in the kit GLB"
		)
		assert_true(model.find_child(MapViewHoistRope.ANCHOR_MARKER, true, false) != null)
	if rope != null and model != null:
		assert_eq(rope.scale, Vector3.ONE, "rope is not stretched by the footprint fit")
		# Kit rope is 2.35 m (report hoist markers); the fit scales height only.
		var expected := 2.35 * model.scale.y
		assert_almost_eq(float(rope.get_meta(&"rope_length")), expected, 0.02)
		assert_true(rope.position.y > model.scale.y * 8.0, "rope hangs from the gable beam")
	node.free()


func test_hoist_beam_prop_swaps_baked_rope_and_hook() -> void:
	var node := MapViewMeshBuilder.build_prop(
		{
			"id": MapTypes.PROP_KIND_HOIST_BEAM,
			"kind": MapTypes.PROP_KIND_HOIST_BEAM,
			"position": Vector2.ZERO,
			"house_tier": PropStyleVariants.HOUSE_TIER_MERCHANT_STONE,
		},
		MapTypes.DEFAULT_CELL_SIZE
	)
	var model := node.get_node_or_null("HoistBeamModel") as Node3D
	assert_true(model != null)
	if model != null:
		assert_true(model.find_child("Hook", true, false) == null, "baked hook removed")
		assert_true(model.find_child("Rope*", true, false) == null, "baked rope removed")
		var rope := model.find_child(MapViewHoistRope.NODE_NAME, true, false) as MeshInstance3D
		assert_true(rope != null, "prop hoist gets a live rope")
		if rope != null:
			assert_true(float(rope.get_meta(&"rope_length")) > 0.5)
	node.free()


func test_town_hall_hoist_uses_live_rope() -> void:
	var root := Node3D.new()
	TownHallModel.add_details(root, {"id": &"town_hall"}, Vector2(12.0, 8.0), 6.0)
	var rope := root.get_node_or_null("TownHallHoistRope") as MeshInstance3D
	assert_true(rope != null)
	if rope != null:
		assert_true(rope.get_meta(&"hoist_rope", false), "town hall rope is a MapViewHoistRope")
	root.free()
