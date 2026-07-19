extends "res://tests/godot/map_view_3d_test_base.gd"

func test_enclosed_interior_suppresses_countryside_surroundings() -> void:
	var definition := KalevSmithyDefinition.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	assert_false(view.has_node("Surroundings/Apron"), "interior shell must not paint meadow apron")
	assert_false(view.has_node("Surroundings/SpruceCanopies"), "interior shell must not spawn treeline")
	assert_true(view.has_node("InteriorShell/Ceiling"), "enclosed interiors need a shared ceiling for first-person")
	var ceiling := view.get_node("InteriorShell/Ceiling") as MeshInstance3D
	var wall_height := MapViewMeshBuilder.interior_shell_wall_height_world(definition)
	var ceiling_plane := wall_height + MapViewMeshBuilderConfig.INTERIOR_CEILING_FIRST_PERSON_HEADROOM
	assert_true(
		is_equal_approx(
			ceiling.position.y,
			ceiling_plane - MapViewMeshBuilderConfig.INTERIOR_CEILING_THICKNESS * 0.5
		),
		"ceiling must rest on interior wall tops with no sky band between them"
	)
	assert_false(view.is_interior_shell_visible(), "top-down view must start with the ceiling hidden")
	assert_true(view.get_node("InteriorShell").get_child_count() >= 3, "ceiling needs exposed timber beams")
	var window_landmarks := 0
	for landmark in definition.view_landmarks:
		if landmark.get("kind", &"") == &"interior_window":
			window_landmarks += 1
			var node := view.get_node("Landmarks/Landmark_%s" % String(landmark["id"]))
			assert_true(node.has_node("InteriorWindowLights"), "interior windows need cycle-driven daylight")
			assert_true(node.has_node("Window0"), "interior window needs glazed pane")
			assert_true(node.has_node("WallAbove0"), "interior windows should fill void above the lintel")
	assert_eq(window_landmarks, 4)
	var candle := view.get_node("Props/Prop_table_candle") as Node3D
	var table := view.get_node("Props/Prop_food_table") as Node3D
	assert_true(candle.has_node("CandleLight"), "table candle needs local light controller")
	assert_true(
		candle.position.y >= table.position.y + 0.45,
		"table candle must sit on the table surface, not under it"
	)
	view.apply_cycle_progress(0.5)
	view.apply_cycle_progress(0.0)
	view.free()


func test_kalev_smithy_floor_is_flat() -> void:
	var definition := KalevSmithyDefinition.create()
	var grid := MapBuilder.build(definition)
	MapViewMeshBuilder.ensure_height_field(definition, grid)
	for sample in [Vector2(6.5, 7.0), Vector2(20.0, 8.0), Vector2(13.0, 3.0), Vector2(2.0, 11.0)]:
		assert_eq(
			MapViewMeshBuilder.ground_height(definition, sample),
			0.0,
			"interior smithy floor must stay flat at %s" % sample
		)


func test_kalev_smithy_door_sits_on_south_wall_boundary() -> void:
	var definition := KalevSmithyDefinition.create()
	var transition: Dictionary
	for candidate in definition.transitions:
		if candidate.get("id") == &"door_courtyard":
			transition = candidate
			break
	var door := MapViewMeshBuilder.build_transition_door(
		transition,
		definition.cell_size,
		MapViewMeshBuilder.interior_shell_wall_height_world(definition)
	)
	assert_true(door.has_node("Panel"), "smithy door needs a solid panel")
	assert_true(door.has_node("OpeningHead"), "smithy door should fill the wall headroom")
	var rect: Rect2 = transition["rect"]
	var expected_boundary := rect.position.y * MapViewBridge.world_scale(definition.cell_size)
	assert_true(is_equal_approx(door.position.z, expected_boundary), "smithy door must sit flush with the south wall")
	door.free()


func test_outdoor_maps_do_not_spawn_interior_ceiling() -> void:
	var definition := SmithyCourtyard.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	view.activate_all_chunks()
	assert_false(view.has_node("InteriorShell/Ceiling"), "outdoor maps must stay open to the sky")
	view.free()


func test_interior_walls_skip_segment_caps() -> void:
	var definition := KalevSmithyDefinition.create()
	for building in definition.buildings:
		if building.get("kind", &"") != MapTypes.BUILDING_KIND_INTERIOR_WALL:
			continue
		var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
		assert_false(node.has_node("Cap"), "%s: interior walls rely on the shared ceiling" % building["id"])
		node.free()


func test_kalev_smithy_interior_walls_show_period_structure() -> void:
	var definition := KalevSmithyDefinition.create()
	var found_plaster := false
	var found_smoked_plaster := false
	for building in definition.buildings:
		if building.get("kind", &"") != MapTypes.BUILDING_KIND_INTERIOR_WALL:
			continue
		var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
		assert_true(node.has_node("StonePlinth_south") or node.has_node("StonePlinth_east"), "%s needs a limestone plinth" % building["id"])
		assert_true(node.has_node("Post_south_00") or node.has_node("Post_east_00"), "%s needs exposed timber posts" % building["id"])
		var material: StringName = building.get("wall_material", &"")
		if material == &"plaster":
			found_plaster = true
		elif material == &"smoked_plaster":
			found_smoked_plaster = true
			assert_true(node.has_node("Soot_south_00") or node.has_node("Soot_east_00"), "%s needs a soot wash" % building["id"])
		node.free()
	assert_true(found_plaster, "smithy needs a clean lime-plaster living bay")
	assert_true(found_smoked_plaster, "smithy needs a smoke-darkened forge bay")


func test_town_surroundings_use_authored_neighbor_edges() -> void:
	var definition := LowerTownSlice.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	for side in ["west", "north", "east", "south"]:
		assert_true(view.has_node("Surroundings/Neighbor_%s" % side), "%s edge needs a neighbor preview" % side)
		assert_true(view.has_node("Surroundings/Neighbor_%s/Terrain_Ground" % side) or view.get_node("Surroundings/Neighbor_%s" % side).get_child_count() > 0)
	view.free()


func test_lower_town_scatter_includes_puddles_on_worked_ground() -> void:
	var definition := LowerTownSlice.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	view.activate_all_chunks()
	var found := false
	for chunk in view.get_node("Scatter").get_children():
		if chunk.has_node("Puddles"):
			found = true
			break
	assert_true(found, "lower town worked ground should spawn reflective puddles")
	view.free()


func test_grass_and_tree_detail_use_generated_meshes_and_wind_materials() -> void:
	var definition := SmithyCourtyard.create()
	definition.surroundings_sides = {&"east": &"woodland"}
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	view.activate_all_chunks()
	var tufts := view.get_node("Scatter/Tufts") as MultiMeshInstance3D
	assert_true(tufts.multimesh.mesh is ArrayMesh, "grass must use blade geometry instead of a cone primitive")
	assert_true(tufts.material_override is ShaderMaterial, "grass blades must carry the wind shader")
	assert_eq(
		tufts.cast_shadow,
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"grass must not cast shadows while vertex wind animates"
	)
	for path in ["Surroundings/SpruceCanopies", "Surroundings/LeafCanopies"]:
		var canopy := view.get_node(path) as MultiMeshInstance3D
		assert_true(canopy.multimesh.mesh is ArrayMesh, "%s must use a multi-lobed generated mesh" % path)
		assert_true(canopy.material_override is ShaderMaterial, "%s must carry canopy sway" % path)
	view.free()


func test_houses_get_gabled_roofs_and_walls_get_caps() -> void:
	var definition := SmithyCourtyard.create()
	for building in definition.buildings:
		var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
		assert_true(node.has_node("Walls"), "every building needs a wall prism")
		if building["kind"] == MapTypes.BUILDING_KIND_HOUSE:
			assert_true(node.has_node("Roof"), "%s: houses need a gabled roof" % building["id"])
			var roof := node.get_node("Roof") as MeshInstance3D
			assert_true(roof.mesh is ArrayMesh, "%s: gabled roof must be generated geometry" % building["id"])
		else:
			assert_true(node.has_node("Cap"), "%s: walls need a flat cap" % building["id"])
		node.free()


func test_building_uv_scale_grows_with_wall_span() -> void:
	var reference := MapViewMaterials.BUILDING_UV_REFERENCE_SIZE
	var short_uv := MapViewMaterials.building_uv_scale(MapViewMaterials.PATTERN_BRICK, reference)
	var long_uv := MapViewMaterials.building_uv_scale(
		MapViewMaterials.PATTERN_BRICK,
		Vector3(24.0, reference.y, reference.z)
	)
	assert_true(
		is_equal_approx(short_uv.x, MapViewMaterials.BUILDING_UV_SCALE[MapViewMaterials.PATTERN_BRICK].x),
		"reference footprint must keep the legacy brick repeat count"
	)
	assert_true(long_uv.x > short_uv.x * 5.0, "long walls must tile more bricks instead of stretching them")


func test_city_wall_masonry_uses_direction_independent_triplanar_scale() -> void:
	var definition := LowerTownSlice.create()
	var expected_density := MapViewMaterials.building_uv_density(MapViewMaterials.PATTERN_LIMESTONE)
	var wall_ids: Array[StringName] = [&"city_wall_north", &"city_wall_southwest"]
	var checked := 0
	for building in definition.buildings:
		if building["id"] not in wall_ids:
			continue
		var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
		var walls := node.get_node("Walls") as MeshInstance3D
		var material := walls.material_override as StandardMaterial3D
		assert_true(material.uv1_triplanar, "%s must not use direction-dependent BoxMesh UVs" % building["id"])
		assert_false(material.uv1_world_triplanar, "%s projection must stay anchored to the wall" % building["id"])
		assert_true(
			material.uv1_scale.is_equal_approx(expected_density),
			"%s must keep constant masonry density on both wall axes" % building["id"]
		)
		checked += 1
		node.free()
	assert_eq(checked, wall_ids.size(), "test needs perpendicular Lower Town wall segments")


func test_chimney_smoke_varies_by_building_and_time_of_day() -> void:
	var smoke_material := MapViewMaterials.smoke()
	assert_eq(smoke_material.albedo_texture, null, "smoke must stay texture-free")
	assert_true(smoke_material.vertex_color_use_as_albedo, "smoke material must apply the particle lifetime fade")

	var definition := LowerTownSlice.create()
	var house_ids: Array[StringName] = []
	var with_smoke := 0
	var without_smoke := 0
	var color_signatures: Dictionary = {}
	for building in definition.buildings:
		if building["kind"] != MapTypes.BUILDING_KIND_HOUSE:
			continue
		house_ids.append(building["id"])
		var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
		assert_true(node.has_node("Chimney"), "%s: every house keeps a chimney stack" % building["id"])
		var chimney := node.get_node("Chimney")
		assert_true(chimney.has_node("Flue"), "%s: chimney must expose a dark flue" % building["id"])
		var flue := chimney.get_node("Flue") as MeshInstance3D
		var flue_material := flue.material_override as StandardMaterial3D
		assert_true(
			flue_material.albedo_color.v < 0.2,
			"%s: flue interior must read darker than stone walls" % building["id"]
		)
		if node.has_node("ChimneySmoke"):
			with_smoke += 1
			var smoke := node.get_node("ChimneySmoke") as ChimneySmoke3D
			var process := smoke.process_material as ParticleProcessMaterial
			assert_true(smoke.draw_pass_1 is ArrayMesh, "%s: smoke puffs must use rounded geometry" % building["id"])
			var puff_mesh := smoke.draw_pass_1 as ArrayMesh
			var puff_vertices: PackedVector3Array = puff_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			assert_eq(puff_vertices.size(), 9, "%s: smoke puffs must be eight-sided" % building["id"])
			var puff_arrays: Array = puff_mesh.surface_get_arrays(0)
			assert_eq(puff_arrays[Mesh.ARRAY_COLOR], null, "%s: smoke puffs must not use vertex color gradients" % building["id"])
			assert_eq(
				smoke.preprocess,
				ChimneySmoke3D.SMOKE_PREWARM_SECONDS,
				"%s: smoke must prewarm enough to remain visible at the chimney mouth" % building["id"]
			)
			var building_seed := String(building["id"]).hash()
			var expected_day_amount := (22 + ((building_seed >> 5) % 14)) * 2
			assert_eq(smoke.amount, expected_day_amount, "%s: day smoke amount must be doubled" % building["id"])
			var ramp_texture := process.color_ramp as GradientTexture1D
			var ramp: Gradient = ramp_texture.gradient
			color_signatures[building["id"]] = ramp.get_color(1)
			var peak_alpha := ramp.sample(0.1).a
			assert_true(peak_alpha > ramp.sample(0.4).a, "%s: smoke must begin fading after its initial puff" % building["id"])
			assert_true(ramp.sample(0.4).a > ramp.sample(0.75).a, "%s: smoke must become more transparent over time" % building["id"])
			assert_eq(ramp.sample(1.0).a, 0.0, "%s: smoke must be fully transparent before removal" % building["id"])
			assert_false(process.turbulence_enabled, "%s: smoke sway must come from wind gravity, not turbulence" % building["id"])
			assert_eq(
				process.emission_shape,
				ParticleProcessMaterial.EMISSION_SHAPE_POINT,
				"%s: smoke must emit from the chimney mouth" % building["id"]
			)
			assert_eq(process.direction, Vector3.UP, "%s: smoke must launch upward from the chimney" % building["id"])
			assert_true(process.spread <= 12.0, "%s: smoke spread must stay tight at the chimney mouth" % building["id"])
		else:
			without_smoke += 1
		node.free()

	assert_true(with_smoke > 0, "at least one house must emit smoke")
	assert_true(without_smoke > 0, "some houses must omit smoke entirely")
	assert_true(color_signatures.size() >= 2, "smoke tints must vary across houses")

	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	var day_emitters: Array[bool] = []
	for building_id in house_ids:
		var building_node := view.get_node("Buildings/Building_%s" % String(building_id))
		var smoke := building_node.get_node_or_null("ChimneySmoke") as ChimneySmoke3D
		day_emitters.append(smoke != null and smoke.emitting)
	view.set_time_of_day(MapView3D.TIME_NIGHT)
	var night_changed := false
	for index in house_ids.size():
		var building_node := view.get_node("Buildings/Building_%s" % String(house_ids[index]))
		var smoke := building_node.get_node_or_null("ChimneySmoke") as ChimneySmoke3D
		var night_emitting := smoke != null and smoke.emitting
		if night_emitting != day_emitters[index]:
			night_changed = true
	view.free()
	assert_true(night_changed, "day/night must change which chimneys emit smoke")


func test_transition_door_has_readable_frame_panel_and_handle() -> void:
	var definition := LowerTownSlice.create()
	var transition: Dictionary
	for candidate in definition.transitions:
		if candidate.get("id") == &"smithy_door_transition":
			transition = candidate
			break
	assert_false(transition.is_empty(), "smithy door must stay a framed building entry")
	var door := MapViewMeshBuilder.build_transition_door(transition, definition.cell_size)
	assert_true(door.has_node("Panel"), "door needs a solid panel")
	assert_true(door.has_node("FrameLeft"), "door needs a left frame")
	assert_true(door.has_node("FrameRight"), "door needs a right frame")
	assert_true(door.has_node("Lintel"), "door needs a lintel")
	assert_true(door.has_node("Handle"), "door needs a visible handle")
	var rect: Rect2 = transition["rect"]
	var expected_boundary := rect.position.y * MapViewBridge.world_scale(definition.cell_size)
	assert_true(is_equal_approx(door.position.z, expected_boundary), "door must sit flush with the smithy wall")
	door.free()


func test_transition_marker_is_translucent_and_covers_trigger() -> void:
	var definition := LowerTownSlice.create()
	var transition: Dictionary
	for candidate in definition.transitions:
		if candidate.get("id") == &"vana_turg_boundary":
			transition = candidate
			break
	var marker := MapViewMeshBuilder.build_transition_marker(transition, definition.cell_size)
	var surface := marker.get_node("Surface") as MeshInstance3D
	var mesh := surface.mesh as BoxMesh
	var rect: Rect2 = transition["rect"]
	var scale := MapViewBridge.world_scale(definition.cell_size)
	assert_true(mesh.size.is_equal_approx(Vector3(rect.size.x * scale, MapViewMeshBuilder.TRANSITION_MARKER_HEIGHT, rect.size.y * scale)))
	var material := surface.material_override as StandardMaterial3D
	assert_true(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_true(material.albedo_color.a > 0.0 and material.albedo_color.a < 1.0)
	(marker as TransitionMarker3D).set_focused(true)
	assert_true(is_equal_approx(material.albedo_color.a, TransitionMarker3D.FOCUS_ALPHA))
	(marker as TransitionMarker3D).set_focused(false)
	assert_true(is_equal_approx(material.albedo_color.a, TransitionMarker3D.IDLE_ALPHA))
	marker.free()


func test_every_prop_kind_builds_parametric_geometry() -> void:
	for kind in MapTypes.ALL_PROP_KINDS:
		var node := MapViewMeshBuilder.build_prop(
			{"id": kind, "kind": kind, "position": Vector2(64.0, 64.0)},
			MapTypes.DEFAULT_CELL_SIZE
		)
		assert_true(node.get_child_count() >= 1, "%s: prop must produce geometry" % kind)
		assert_false(node.has_node("Marker"), "%s: prop must not fall back to the unknown-kind marker" % kind)
		assert_eq(node.position, Vector3(2.0, 0.0, 2.0), "%s: prop anchors at the definition position" % kind)
		node.free()


