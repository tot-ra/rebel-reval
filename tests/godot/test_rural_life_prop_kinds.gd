extends "res://tests/godot/map_view_3d_test_base.gd"

## P0-107: rural-life prop kinds compile and build readable 3D meshes.


func test_all_rural_life_kinds_are_registered() -> void:
	assert_eq(
		MapTypes.RURAL_LIFE_PROP_KINDS.size(),
		15,
		"P0-107 rural prop-kind set plus authored field tools must stay in sync with MapTypes"
	)
	for kind in MapTypes.RURAL_LIFE_PROP_KINDS:
		assert_true(MapTypes.ALL_PROP_KINDS.has(kind), "%s must be in ALL_PROP_KINDS" % kind)


func test_rural_life_props_build_mesh_children() -> void:
	for kind in MapTypes.RURAL_LIFE_PROP_KINDS:
		var prop := {
			"id": StringName("test.%s" % kind),
			"kind": kind,
			"position": Vector2(64, 64),
		}
		var node := MapViewMeshBuilderProps.build_prop(prop, MapTypes.DEFAULT_CELL_SIZE)
		assert_true(node.get_child_count() > 0, "%s must emit at least one mesh child" % kind)
		node.free()


func test_rural_life_props_render_day_and_night() -> void:
	for kind in MapTypes.RURAL_LIFE_PROP_KINDS:
		var prop := {
			"id": StringName("view.%s" % kind),
			"kind": kind,
			"position": Vector2(96, 96),
		}
		for time_of_day in [MapVisualStyle.TIME_DAY, MapVisualStyle.TIME_NIGHT]:
			var node := MapPropRenderer.create_prop(prop, MapVisualStyle.TARGET_CLEAN_PAINTED, time_of_day)
			assert_true(node.get_child_count() > 1, "%s %s needs shadow plus body" % [kind, time_of_day])
			node.free()



func test_authored_farm_tools_keep_readable_metric_silhouettes_and_pbr() -> void:
	var expected := {
		MapTypes.PROP_KIND_PITCHFORK: {
			"node": "PitchforkModel",
			"height": Vector2(2.0, 2.04),
			"triangles": 376,
			"materials": 2,
		},
		MapTypes.PROP_KIND_SCYTHE: {
			"node": "ScytheModel",
			"height": Vector2(1.49, 1.53),
			"triangles": 388,
			"materials": 3,
		},
		MapTypes.PROP_KIND_SICKLE: {
			"node": "SickleModel",
			"height": Vector2(0.45, 0.48),
			"triangles": 140,
			"materials": 3,
		},
		MapTypes.PROP_KIND_RAKE: {
			"node": "RakeModel",
			"height": Vector2(1.68, 1.72),
			"triangles": 312,
			"materials": 1,
		},
		MapTypes.PROP_KIND_WOODEN_SHOVEL: {
			"node": "WoodenShovelModel",
			"height": Vector2(1.44, 1.47),
			"triangles": 136,
			"materials": 1,
		},
	}
	for kind in expected:
		var node := MapViewMeshBuilderProps.build_prop({
			"id": StringName("asset.%s" % kind),
			"kind": kind,
			"position": Vector2.ZERO,
		}, MapTypes.DEFAULT_CELL_SIZE)
		var spec: Dictionary = expected[kind]
		var model := node.get_node(String(spec["node"])) as Node3D
		assert_true(model.get_meta(&"production_medieval_hand_tool", false))
		var metrics := _tool_metrics(model)
		var height: Vector2 = spec["height"]
		assert_true(metrics["bounds"].size.y >= height.x and metrics["bounds"].size.y <= height.y, "%s height must stay plausible" % kind)
		assert_true(metrics["bounds"].position.y >= -0.001, "%s must rest on the ground plane" % kind)
		assert_eq(metrics["triangles"], spec["triangles"], "%s geometry must stay deterministic" % kind)
		assert_eq(metrics["materials"], spec["materials"], "%s material identities must stay stable" % kind)
		assert_eq(metrics["pbr_materials"], spec["materials"], "%s needs albedo, normal, and roughness on every material" % kind)
		node.free()


func _tool_metrics(model: Node3D) -> Dictionary:
	var bounds := AABB()
	var first := true
	var triangles := 0
	var materials: Dictionary = {}
	var pbr_materials: Dictionary = {}
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var child_bounds := mesh_instance.transform * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		for surface_index in mesh_instance.mesh.get_surface_count():
			triangles += mesh_instance.mesh.surface_get_array_index_len(surface_index) / 3
			var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			if material == null:
				continue
			materials[material.resource_name] = true
			if material.albedo_texture != null and material.normal_enabled and material.normal_texture != null and material.roughness_texture != null:
				pbr_materials[material.resource_name] = true
	return {
		"bounds": bounds,
		"triangles": triangles,
		"materials": materials.size(),
		"pbr_materials": pbr_materials.size(),
	}

func test_unknown_rural_life_kind_fails_blueprint_compile() -> void:
	var blueprint := MapBlueprint.new(
		&"rural_life_invalid_kind",
		&"loc.debug",
		Vector2i(12, 12),
		MapTypes.TERRAIN_GRASS,
	)
	blueprint.scope = &"prototype"
	blueprint.active = false
	blueprint.player_spawn(&"spawn.main", Vector2i(2, 2))
	blueprint.prop(&"bad.prop", &"pig_pen", Vector2i(3, 3))
	var result := MapBlueprintCompiler.compile_with_diagnostics(blueprint)
	assert_false(result.is_ok(), "seeded invalid prop kind must fail compile")
	for error in result.errors:
		if error.contains("prop kind is unknown"):
			return
	fail("Expected prop kind is unknown, got: %s" % result.errors)
