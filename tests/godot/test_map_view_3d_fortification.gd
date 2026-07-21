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
			assert_true(node.has_node("DoorStrap0"), "%s: street doors need iron binding straps" % building["id"])
		assert_true(node.has_node("Window0"), "%s: every house needs at least one window" % building["id"])
		assert_true(node.has_node("WindowFrameL0"), "%s: windows need an outer timber frame" % building["id"])
		assert_true(node.has_node("WindowMullionV0"), "%s: windows need inner mullions" % building["id"])
		assert_true(node.has_node("ShutterL0"), "%s: windows need open timber shutters" % building["id"])
		assert_true(node.has_node("RidgeBoard"), "%s: roofs need a ridge board" % building["id"])
		assert_true(node.has_node("Plinth"), "%s: houses need a stone plinth" % building["id"])
		var glass := node.get_node("Window0") as MeshInstance3D
		var glass_mat := glass.material_override as StandardMaterial3D
		assert_true(glass_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "%s: window glass must be translucent" % building["id"])
		assert_true(glass_mat.albedo_color.a < 0.75, "%s: window glass must not read as opaque bright panels" % building["id"])
		# Style-specific dressing must stay historically grounded (no Fachwerk braces).
		assert_false(node.has_node("Brace-1") or node.has_node("Brace1"), "%s: diagonal Fachwerk braces are not Tallinn vernacular" % building["id"])
		var style := MapViewMeshBuilderBuildingHouses.house_style(building)
		match style:
			MapViewMeshBuilderConfig.HOUSE_STYLE_LOG:
				assert_true(node.has_node("LogEnd_0_-1_-1") or node.has_node("LogEnd_0_1_1"), "%s: log houses need corner heads" % building["id"])
			MapViewMeshBuilderConfig.HOUSE_STYLE_STONE, MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK:
				assert_true(node.has_node("Cornice"), "%s: masonry houses need an eaves cornice" % building["id"])
			MapViewMeshBuilderConfig.HOUSE_STYLE_PLANK:
				assert_true(node.has_node("CornerBoard_-1_-1") or node.has_node("CornerBoard_1_1"), "%s: plank houses need corner boards" % building["id"])
			MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER:
				assert_true(node.has_node("CornerPost_-1_-1") or node.has_node("CornerPost_1_1"), "%s: plastered houses keep timber posts" % building["id"])
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
				# hinke_tower is authored tower=false (stub mass); only true towers get roofs.
				if bool(building.get("tower", false)):
					assert_true(node.has_node("TowerRoof"), "%s needs a conical red-tile roof" % building["id"])
					assert_true(node.has_node("Pennant"), "%s needs a wind-readable tower pennant" % building["id"])
					var pennant := node.get_node("Pennant") as MeshInstance3D
					assert_true(
						pennant.material_override is ShaderMaterial,
						"%s pennant must use flag cloth wind" % building["id"]
					)
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
	var viru_arch_def: Dictionary = {}
	for landmark in definition.view_landmarks:
		if landmark["id"] == &"viru_gate_arch":
			viru_arch_def = landmark
			break
	assert_false(viru_arch_def.is_empty(), "Viru Gate needs its arch landmark")
	var arch := MapViewMeshBuilder.build_landmark(viru_arch_def, definition.cell_size)
	assert_true(arch.has_node("Bridge"), "gate arch needs a bridging mass")
	assert_true(arch.has_node("Jamb0"), "gate arch needs stone jambs to close side holes")
	assert_true(arch.has_node("GateDoor0"), "Viru Gate needs open gate doors")
	assert_true(arch.has_node("GateDoor0/Strap0"), "gate doors need iron binding straps")
	var bridge := arch.get_node("Bridge") as MeshInstance3D
	var bridge_mesh := bridge.mesh as BoxMesh
	assert_true(
		bridge.position.y - bridge_mesh.size.y * 0.5 >= 2.0,
		"the arch must clear the frozen 2.0-unit character"
	)
	var viru_door := arch.get_node("GateDoor0") as MeshInstance3D
	var viru_door_mesh := viru_door.mesh as BoxMesh
	assert_true(
		viru_door_mesh.size.x <= MapViewMeshBuilderConfig.GATE_DOOR_MAX_LEAF + 0.05
		and viru_door_mesh.size.z <= MapViewMeshBuilderConfig.GATE_DOOR_MAX_LEAF + 0.05,
		"gate leaves must stay character-scale, not span the gatehouse depth"
	)
	var wood_mat := MapViewMaterials.role(&"wood")
	assert_true(
		(viru_door.material_override as StandardMaterial3D).albedo_color.is_equal_approx(wood_mat.albedo_color),
		"Viru Gate doors should use wood"
	)
	var threshold := arch.get_node("Threshold") as MeshInstance3D
	var threshold_mesh := threshold.mesh as BoxMesh
	assert_true(
		threshold_mesh.size.x < bridge_mesh.size.x * 0.5 or threshold_mesh.size.z < bridge_mesh.size.z * 0.5,
		"threshold must be a narrow sill, not a masonry slab across the whole passage"
	)
	var jamb := arch.get_node("Jamb0") as MeshInstance3D
	assert_true(
		(jamb.material_override as StandardMaterial3D).uv1_triplanar,
		"gate jambs need triplanar limestone so courses stay dense on long faces"
	)
	arch.free()

	var south_definition := SouthQuarterDefinition.create()
	var karja_arch_def: Dictionary = {}
	for landmark in south_definition.view_landmarks:
		if landmark["id"] == &"karja_gate_arch":
			karja_arch_def = landmark
			break
	assert_false(karja_arch_def.is_empty(), "Karja Gate needs its arch landmark")
	var karja_arch := MapViewMeshBuilder.build_landmark(karja_arch_def, south_definition.cell_size)
	assert_true(karja_arch.has_node("GateDoor0"), "Karja Gate needs open metal doors")
	var karja_door := karja_arch.get_node("GateDoor0") as MeshInstance3D
	var metal_mat := MapViewMaterials.role(&"metal")
	assert_true(
		(karja_door.material_override as StandardMaterial3D).albedo_color.is_equal_approx(metal_mat.albedo_color),
		"Karja Gate doors should use metal"
	)
	karja_arch.free()


func test_district_boundaries_use_ground_markers_and_real_neighbor_previews() -> void:
	var definition := LowerTownSlice.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	assert_eq(view.get_node("Doors").get_child_count(), 1, "only the smithy remains a framed door")
	for side in ["west", "north", "east", "south"]:
		assert_true(view.has_node("Surroundings/Neighbor_%s" % side), "%s edge needs its authored neighbor" % side)
		assert_true(view.get_node("Surroundings/Neighbor_%s/Buildings" % side).get_child_count() > 0, "%s preview needs real neighboring buildings" % side)
	assert_eq(view.get_node("TransitionMarkers").get_child_count(), 4, "district exits need subtle ground cues")
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

func test_viru_gate_wall_walk_access_is_visible_and_traversable() -> void:
	var definition := LowerTownSlice.create()
	var stairs: Dictionary = {}
	var platform: Dictionary = {}
	for prop in definition.props:
		if prop["id"] == &"viru_wall_walk_stairs":
			stairs = prop
		elif prop["id"] == &"viru_wall_walk_platform":
			platform = prop
	assert_false(stairs.is_empty(), "Viru Gate needs an authored wall stair")
	assert_false(platform.is_empty(), "Viru Gate needs a walkable wall-top corridor")
	var stair_node := MapViewMeshBuilder.build_prop(stairs, definition.cell_size, definition)
	var platform_node := MapViewMeshBuilder.build_prop(platform, definition.cell_size, definition)
	assert_true(stair_node.has_node("WallStairStep0"), "wall access must render wooden treads")
	assert_true(stair_node.has_node("WallStairLanding"), "wall access needs a level top landing")
	assert_true(stair_node.has_node("WallStairRail1"), "wall stairs need timber handrails")
	assert_true(platform_node.has_node("WallWalkPlatform"), "the elevated patrol corridor needs a plank deck")
	var stair_rect: Rect2 = stairs["footprint"]
	var platform_rect: Rect2 = platform["footprint"]
	var bottom := Vector2(stair_rect.position.x + 1.0, stair_rect.get_center().y)
	var top := Vector2(stair_rect.end.x - 1.0, stair_rect.get_center().y)
	assert_true(MapWallWalkAccess.elevation_at(definition, top) > MapWallWalkAccess.elevation_at(definition, bottom))
	var wall: Dictionary = {}
	for building in definition.buildings:
		if building["id"] == &"city_wall_north":
			wall = building
			break
	assert_false(wall.is_empty())
	var grid := MapBuilder.build(definition)
	var landing := Vector2(platform_rect.position.x + 1.0, stair_rect.get_center().y)
	var wall_rect: Rect2 = wall["footprint"]
	var entry := platform_rect.intersection(wall_rect).get_center()
	var north_walk := Vector2(entry.x, platform_rect.position.y + float(definition.cell_size) * 0.5)
	var south_walk := Vector2(entry.x, platform_rect.end.y - float(definition.cell_size) * 0.5)
	assert_true(MapVerification.is_walkable_point(definition, grid, bottom))
	assert_true(MapVerification.is_walkable_point(definition, grid, landing))
	assert_true(MapVerification.is_walkable_point(definition, grid, entry), "stair landing must enter the wall gallery")
	assert_true(MapVerification.is_walkable_point(definition, grid, platform_rect.get_center()))
	assert_true(
		MapVerification.route_exists_exact(definition, grid, entry, north_walk),
		"the opened gallery must allow movement north along the wall"
	)
	assert_true(
		MapVerification.route_exists_exact(definition, grid, entry, south_walk),
		"the opened gallery must allow movement south along the wall"
	)
	assert_false(MapWallWalkAccess.point_blocked_by_building(definition, wall, entry))
	assert_true(
		MapWallWalkAccess.point_blocked_by_building(
			definition,
			wall,
			Vector2(wall_rect.get_center().x, platform_rect.position.y - 1.0)
		),
		"the fortification outside the authored gallery must remain sealed"
	)
	var wall_body := MapBuildingRenderer.create_building(
		wall,
		MapVisualStyle.TARGET_CLEAN_PAINTED,
		MapVisualStyle.TIME_DAY,
		definition
	)
	assert_false(MapBuildingRenderer.footprint_blocks_point(wall_body, entry))
	wall_body.free()
	stair_node.free()
	platform_node.free()
