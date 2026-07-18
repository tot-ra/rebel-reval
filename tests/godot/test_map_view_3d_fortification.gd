extends "res://tests/godot/map_view_3d_test_base.gd"

func test_houses_get_facade_doors_and_windows() -> void:
	var definition := LowerTownSlice.create()
	for building in definition.buildings:
		if building["kind"] != MapTypes.BUILDING_KIND_HOUSE:
			continue
		var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
		if building.get("door_side", &"south") == &"none":
			assert_false(node.has_node("Door"), "%s: door_side none must suppress the plain door" % building["id"])
		else:
			assert_true(node.has_node("Door"), "%s: every house needs a street door" % building["id"])
		assert_true(node.has_node("Window0"), "%s: every house needs at least one window" % building["id"])
		assert_true(node.has_node("WindowFrameL0"), "%s: windows need an outer timber frame" % building["id"])
		assert_true(node.has_node("WindowMullionV0"), "%s: windows need inner mullions" % building["id"])
		var glass := node.get_node("Window0") as MeshInstance3D
		var glass_mat := glass.material_override as StandardMaterial3D
		assert_true(glass_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "%s: window glass must be translucent" % building["id"])
		assert_true(glass_mat.albedo_color.a < 0.75, "%s: window glass must not read as opaque bright panels" % building["id"])
		node.free()


func test_town_wall_gets_battlements_and_gate_arch_clears_character() -> void:
	var definition := LowerTownSlice.create()
	for building in definition.buildings:
		if building["id"] in [&"city_wall_north", &"viru_gate_north_tower", &"hinke_tower"]:
			var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
			if building["id"] == &"city_wall_north":
				assert_true(node.has_node("Merlons"), "straight fortification walls need battlements")
				assert_true(node.has_node("WalkRoof"), "Tallinn wall walks need covered red-tile roofs")
				var cap := node.get_node("Cap") as MeshInstance3D
				var cap_mat := cap.material_override as StandardMaterial3D
				var cap_mesh := cap.mesh as BoxMesh
				var plank_uv := MapViewMaterials.building_uv_scale(MapViewMaterials.PATTERN_PLANK, cap_mesh.size)
				assert_true(
					is_equal_approx(cap_mat.uv1_scale.y, plank_uv.y),
					"wall walk deck must use plank timber, not limestone coping"
				)
			else:
				assert_true(node.has_node("TowerRoof"), "%s needs a conical red-tile roof" % building["id"])
				assert_true((node.get_node("Walls") as MeshInstance3D).mesh is CylinderMesh, "%s must be round" % building["id"])
				if float(building.get("wall_height", 0.0)) >= 220.0:
					assert_true(node.has_node("SlitFrame0"), "%s needs brick-framed arrow slits" % building["id"])
					var slit := node.get_node("Slit0") as MeshInstance3D
					var slit_mat := slit.material_override as StandardMaterial3D
					var window_mat := MapViewMaterials.role(&"window")
					assert_false(
						slit_mat.albedo_color.is_equal_approx(window_mat.albedo_color),
						"%s arrow slits must not reuse glazed house window tint" % building["id"]
					)
			node.free()
	assert_true(definition.view_landmarks.size() >= 1, "Viru Gate needs its arch landmark")
	var arch := MapViewMeshBuilder.build_landmark(definition.view_landmarks[0], definition.cell_size)
	assert_true(arch.has_node("Bridge"), "gate arch needs a bridging mass")
	assert_true(arch.has_node("Jamb0"), "gate arch needs stone jambs to close side holes")
	assert_true(arch.has_node("GateDoor0"), "Viru Gate needs open gate doors")
	var bridge := arch.get_node("Bridge") as MeshInstance3D
	var bridge_mesh := bridge.mesh as BoxMesh
	assert_true(
		bridge.position.y - bridge_mesh.size.y * 0.5 >= 2.0,
		"the arch must clear the frozen 2.0-unit character"
	)
	arch.free()

	var karja_arch_def: Dictionary = {}
	for landmark in definition.view_landmarks:
		if landmark["id"] == &"karja_gate_arch":
			karja_arch_def = landmark
			break
	assert_false(karja_arch_def.is_empty(), "Karja Gate needs its arch landmark")
	var karja_arch := MapViewMeshBuilder.build_landmark(karja_arch_def, definition.cell_size)
	assert_true(karja_arch.has_node("GateDoor0"), "Karja Gate needs open metal doors")
	var karja_door := karja_arch.get_node("GateDoor0") as MeshInstance3D
	var metal_mat := MapViewMaterials.role(&"metal")
	assert_true(
		(karja_door.material_override as StandardMaterial3D).albedo_color.is_equal_approx(metal_mat.albedo_color),
		"Karja Gate doors should use metal"
	)
	karja_arch.free()


func test_district_boundary_gate_arches_frame_street_axis() -> void:
	var definition := LowerTownSlice.create()
	var west_arch_def: Dictionary = {}
	var north_arch_def: Dictionary = {}
	for landmark in definition.view_landmarks:
		match landmark["id"]:
			&"vanaturu_kael_arch":
				west_arch_def = landmark
			&"vene_district_arch":
				north_arch_def = landmark
	assert_false(west_arch_def.is_empty(), "west boundary needs its gate arch")
	assert_false(north_arch_def.is_empty(), "north boundary needs its gate arch")

	var west_arch := MapViewMeshBuilder.build_landmark(west_arch_def, definition.cell_size)
	var west_jamb := west_arch.get_node("Jamb0") as MeshInstance3D
	assert_true(
		absf(west_jamb.position.x) < 0.05 and absf(west_jamb.position.z) > 1.0,
		"Viru street arch must place jambs north and south of the east-west passage"
	)
	west_arch.free()

	var north_arch := MapViewMeshBuilder.build_landmark(north_arch_def, definition.cell_size)
	var north_jamb := north_arch.get_node("Jamb0") as MeshInstance3D
	assert_true(
		absf(north_jamb.position.z) < 0.05 and absf(north_jamb.position.x) > 0.5,
		"Vene street arch must place jambs east and west of the north-south passage"
	)
	north_arch.free()


func test_suburb_boundary_arches_replace_field_doors() -> void:
	var definition := LowerTownSlice.create()
	var suburb_arch_ids: Array[StringName] = [&"viru_suburb_arch", &"karja_suburb_arch"]
	for arch_id in suburb_arch_ids:
		var found := false
		for landmark in definition.view_landmarks:
			if landmark.get("id") == arch_id:
				found = true
				break
		assert_true(found, "missing suburb boundary arch %s" % String(arch_id))

	var view := MapView3D.create(definition, MapBuilder.build(definition))
	var framed_doors := view.get_node("Doors").get_child_count()
	assert_eq(framed_doors, 1, "only the smithy should keep a framed transition door on the slice")
	view.free()


func test_fortification_walls_render_150_percent_taller_than_authored() -> void:
	var definition := LowerTownSlice.create()
	var scale := MapViewBridge.world_scale(definition.cell_size)
	var wall: Dictionary = {}
	var fence: Dictionary = {}
	for building in definition.buildings:
		match building["id"]:
			&"city_wall_north":
				wall = building
			&"smithy_yard_fence_north":
				fence = building
	assert_false(wall.is_empty(), "Lower Town slice must keep its north wall")
	assert_false(fence.is_empty(), "smithy fence must stay available for contrast")
	var wall_node := MapViewMeshBuilder.build_building(wall, definition.cell_size)
	var fence_node := MapViewMeshBuilder.build_building(fence, definition.cell_size)
	var wall_mesh := (wall_node.get_node("Walls") as MeshInstance3D).mesh as BoxMesh
	var fence_mesh := (fence_node.get_node("Walls") as MeshInstance3D).mesh as BoxMesh
	var authored_wall := float(wall["wall_height"]) * scale
	var authored_fence := float(fence["wall_height"]) * scale
	assert_true(
		is_equal_approx(wall_mesh.size.y, authored_wall * MapTypes.FORTIFICATION_HEIGHT_SCALE),
		"city fortifications must render 150% taller than authored heights"
	)
	assert_true(
		is_equal_approx(fence_mesh.size.y, authored_fence),
		"low courtyard fences must keep their authored height"
	)
	wall_node.free()
	fence_node.free()
