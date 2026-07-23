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
