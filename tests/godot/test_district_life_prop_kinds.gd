extends "res://tests/godot/map_view_3d_test_base.gd"

## P2-025: district-life prop kinds compile and build readable 3D meshes.


func test_all_district_life_kinds_are_registered() -> void:
	assert_eq(
		MapTypes.DISTRICT_LIFE_PROP_KINDS.size(),
		18,
		"P2-025 minimum prop-kind set must stay in sync with MapTypes"
	)
	for kind in MapTypes.DISTRICT_LIFE_PROP_KINDS:
		assert_true(MapTypes.ALL_PROP_KINDS.has(kind), "%s must be in ALL_PROP_KINDS" % kind)


func test_district_life_props_build_mesh_children() -> void:
	for kind in MapTypes.DISTRICT_LIFE_PROP_KINDS:
		var prop := {
			"id": StringName("test.%s" % kind),
			"kind": kind,
			"position": Vector2(64, 64),
		}
		var node := MapViewMeshBuilderProps.build_prop(prop, MapTypes.DEFAULT_CELL_SIZE)
		assert_true(node.get_child_count() > 0, "%s must emit at least one mesh child" % kind)
		node.free()


func test_tanning_frame_has_hide_lacing_and_grounded_support() -> void:
	var prop := {
		"id": &"test.tanning_frame",
		"kind": MapTypes.PROP_KIND_TANNING_FRAME,
		"position": Vector2(64, 64),
	}
	var node := MapViewMeshBuilderProps.build_prop(prop, MapTypes.DEFAULT_CELL_SIZE)
	var model := node.find_child("TanningFrameModel", true, false) as Node3D
	assert_true(model != null, "tanning frame needs an authored model root")
	if model == null:
		node.free()
		return
	assert_true(model.get_meta(&"production_tanning_frame_model", false))
	assert_true(model.has_node("TanningFrame/Frame"), "tanning frame needs a braced oak frame")
	assert_true(model.has_node("TanningFrame/Hide"), "tanning frame needs an irregular stretched hide")
	assert_true(model.has_node("TanningFrame/Lacing"), "tanning frame needs visible perimeter lacing")

	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var triangle_count := 0
	var textured_surface_count := 0
	for child in meshes:
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			triangle_count += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
			var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if material != null and material.albedo_texture != null:
				textured_surface_count += 1
	assert_true(triangle_count >= 400 and triangle_count <= 1200, "tanning frame must stay readable and lightweight")
	assert_eq(textured_surface_count, 3, "timber, hide, and rope need embedded painted albedos")
	node.free()


func test_district_life_props_render_day_and_night() -> void:
	for kind in MapTypes.DISTRICT_LIFE_PROP_KINDS:
		var prop := {
			"id": StringName("view.%s" % kind),
			"kind": kind,
			"position": Vector2(96, 96),
		}
		for time_of_day in [MapVisualStyle.TIME_DAY, MapVisualStyle.TIME_NIGHT]:
			var node := MapPropRenderer.create_prop(prop, MapVisualStyle.TARGET_CLEAN_PAINTED, time_of_day)
			assert_true(node.get_child_count() > 1, "%s %s needs shadow plus body" % [kind, time_of_day])
			node.free()


func test_unknown_district_life_kind_fails_blueprint_compile() -> void:
	var blueprint := MapBlueprint.new(
		&"district_life_invalid_kind",
		&"loc.debug",
		Vector2i(12, 12),
		MapTypes.TERRAIN_GRASS,
	)
	blueprint.scope = &"prototype"
	blueprint.active = false
	blueprint.player_spawn(&"spawn.main", Vector2i(2, 2))
	blueprint.prop(&"bad.prop", &"fish_smokehouse", Vector2i(3, 3))
	var result := MapBlueprintCompiler.compile_with_diagnostics(blueprint)
	assert_false(result.is_ok(), "seeded invalid prop kind must fail compile")
	for error in result.errors:
		if error.contains("prop kind is unknown"):
			return
	fail("Expected prop kind is unknown, got: %s" % result.errors)
