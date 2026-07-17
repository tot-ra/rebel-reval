extends "res://tests/godot/test_case.gd"

## P0-052: the 3D orthographic view layer must render the smithy courtyard and
## Lower Town slice definitions without changing any logic-plane result, and
## actor positions synchronized from the logic plane must match anchors within
## one logic cell.

const SmithyCourtyard := preload("res://scripts/map/smithy_courtyard_definition.gd")
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const PLAYER_SCENE := preload("res://player.tscn")
const TRANSITION_MARKER_SCRIPT := preload("res://scripts/map/view3d/transition_marker_3d.gd")


func _view_definitions() -> Array[MapDefinition]:
	return [SmithyCourtyard.create(), LowerTownSlice.create()]


func test_bridge_maps_logic_axes_to_world_axes() -> void:
	var world := MapViewBridge.logic_to_world(Vector2(96.0, 64.0), 32)
	assert_eq(world, Vector3(3.0, 0.0, 2.0), "logic (x, y) must map to world (x, 0, z)")
	var logic := MapViewBridge.world_to_logic(world, 32)
	assert_eq(logic, Vector2(96.0, 64.0), "bridge round trip must be exact")
	assert_eq(
		MapViewBridge.logic_to_world(Vector2(96.0, 64.0), 32),
		MapViewBridge.logic_to_world(Vector2(96.0, 64.0), 32),
		"bridge must be deterministic"
	)
	assert_eq(MapViewBridge.cell_center_to_world(Vector2i(0, 0), 32), Vector3(0.5, 0.0, 0.5))


func test_actor_sync_matches_anchors_within_one_cell() -> void:
	for definition in _view_definitions():
		var grid := MapBuilder.build(definition)
		var view := MapView3D.create(definition, grid)
		var actor := Node3D.new()
		for anchor in definition.interaction_anchors:
			var anchor_position: Vector2 = anchor["position"]
			view.sync_actor(actor, anchor_position)
			var logic_back := MapViewBridge.world_to_logic(actor.position, definition.cell_size)
			assert_true(
				logic_back.distance_to(anchor_position) < float(definition.cell_size),
				"%s: synced actor must sit within one logic cell of anchor %s"
					% [definition.map_id, anchor["id"]]
			)
			var marker := view.get_node("Anchors/%s" % String(anchor["id"])) as Marker3D
			assert_true(marker != null, "%s: anchor marker missing for %s" % [definition.map_id, anchor["id"]])
			assert_true(
				marker.position.distance_to(actor.position) < 1.0,
				"%s: anchor marker and synced actor must agree within one cell" % definition.map_id
			)
		actor.free()
		view.free()


func test_view_renders_definitions_without_touching_logic_results() -> void:
	for definition in _view_definitions():
		var grid := MapBuilder.build(definition)
		var fingerprint_before := grid.fingerprint()
		var definition_fingerprint_before := definition.fingerprint
		var blocked_before := MapVerification.blocked_cells(definition).hash()

		var view := MapView3D.create(definition, grid)

		var terrain := view.get_node("Terrain")
		assert_eq(
			terrain.get_child_count(),
			grid.used_terrain_ids().size(),
			"%s: one terrain region mesh per used terrain" % definition.map_id
		)
		assert_eq(
			view.get_node("Buildings").get_child_count(),
			definition.buildings.size(),
			"%s: one building node per definition building" % definition.map_id
		)
		assert_eq(
			view.get_node("Props").get_child_count(),
			definition.props.size(),
			"%s: one prop node per definition prop" % definition.map_id
		)
		var functional_transition_count := 0
		var highlighted_transition_count := 0
		for transition in definition.transitions:
			if not String(transition.get("destination_scene_id", "")).is_empty():
				functional_transition_count += 1
			if bool(transition.get("highlight_area", false)):
				highlighted_transition_count += 1
		assert_eq(
			view.get_node("Doors").get_child_count(),
			functional_transition_count,
			"%s: every functional transition needs one visible door" % definition.map_id
		)
		assert_eq(
			view.get_node("TransitionMarkers").get_child_count(),
			highlighted_transition_count,
			"%s: every highlighted transition needs one visible ground marker" % definition.map_id
		)

		var camera := view.view_camera()
		assert_eq(camera.projection, Camera3D.PROJECTION_ORTHOGONAL, "camera must be orthographic")
		assert_true(
			camera.rotation_degrees.is_equal_approx(Vector3(-30.0, 45.0, 0.0)),
			"%s: camera must keep the fixed dimetric framing" % definition.map_id
		)

		var sun := view.sun_light()
		assert_true(sun is DirectionalLight3D, "sun must be a DirectionalLight3D")
		assert_true(sun.shadow_enabled, "sun must cast real shadows")

		assert_eq(grid.fingerprint(), fingerprint_before, "%s: grid fingerprint must be unchanged" % definition.map_id)
		assert_eq(definition.fingerprint, definition_fingerprint_before, "%s: definition fingerprint must be unchanged" % definition.map_id)
		assert_eq(
			MapVerification.blocked_cells(definition).hash(),
			blocked_before,
			"%s: collision cells must be unchanged" % definition.map_id
		)
		assert_true(MapVerification.collision_parity(definition), "%s: 2D collision parity must still hold" % definition.map_id)
		assert_true(definition.validate().is_empty(), "%s: definition must still validate" % definition.map_id)
		view.free()


func test_terrain_uses_dense_subcell_geometry() -> void:
	var definition := LowerTownSlice.create()
	var grid := MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid)
	var vertex_count := 0
	for terrain_mesh: MeshInstance3D in view.get_node("Terrain").get_children():
		var mesh := terrain_mesh.mesh as ArrayMesh
		for surface_index in mesh.get_surface_count():
			var index_count := mesh.surface_get_array_index_len(surface_index)
			vertex_count += index_count if index_count > 0 else mesh.surface_get_array_len(surface_index)
	# Tangent generation welds some vertices on animated water surfaces, so the
	# post-commit count can be slightly below the raw 9x triangle budget.
	var minimum_dense_budget := (
		grid.size_cells.x
		* grid.size_cells.y
		* (MapViewMeshBuilder.TERRAIN_SUBDIVISIONS * MapViewMeshBuilder.TERRAIN_SUBDIVISIONS - 1)
		* 6
	)
	assert_true(vertex_count >= minimum_dense_budget, "terrain must retain at least eight visual patches per logic cell")
	view.free()


func test_grass_and_tree_detail_use_generated_meshes_and_wind_materials() -> void:
	var definition := SmithyCourtyard.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	var tufts := view.get_node("Scatter/Tufts") as MultiMeshInstance3D
	assert_true(tufts.multimesh.mesh is ArrayMesh, "grass must use blade geometry instead of a cone primitive")
	assert_true(tufts.material_override is ShaderMaterial, "grass blades must carry the wind shader")
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


func test_chimney_smoke_varies_by_building_and_time_of_day() -> void:
	var smoke_material := MapViewMaterials.smoke()
	assert_ne(smoke_material.albedo_texture, null, "smoke must use a soft puff texture")

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
		if node.has_node("ChimneySmoke"):
			with_smoke += 1
			var smoke := node.get_node("ChimneySmoke") as ChimneySmoke3D
			var process := smoke.process_material as ParticleProcessMaterial
			var ramp_texture := process.color_ramp as GradientTexture1D
			var ramp: Gradient = ramp_texture.gradient
			color_signatures[building["id"]] = ramp.get_color(1)
			assert_true(process.turbulence_enabled, "%s: smoke must use turbulence" % building["id"])
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
	var transition: Dictionary = definition.transitions[0]
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


func test_night_state_is_deterministic_and_darker() -> void:
	var definition := SmithyCourtyard.create()
	var first := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_NIGHT)
	var second := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_NIGHT)
	assert_eq(first.sun_light().light_energy, second.sun_light().light_energy, "night sun energy must be deterministic")
	assert_eq(first.sun_light().light_color, second.sun_light().light_color, "night sun color must be deterministic")
	assert_eq(first.sun_light().rotation_degrees, second.sun_light().rotation_degrees, "night sun angle must be deterministic")
	assert_true(
		MapView3D.SUN_NIGHT_ENERGY <= MapView3D.SUN_DAY_ENERGY * 0.8,
		"night must be at least 20 percent darker than day"
	)
	first.set_time_of_day(MapView3D.TIME_DAY)
	assert_true(
		is_equal_approx(first.sun_light().light_energy, MapView3D.SUN_DAY_ENERGY),
		"day state must restore deterministically"
	)
	first.free()
	second.free()


func test_placeholder_materials_cover_every_terrain() -> void:
	for terrain_id in MapTypes.ALL_TERRAINS:
		var material := MapViewMaterials.terrain(terrain_id, MapTypes.DEFAULT_SEED)
		assert_ne(material.albedo_color, Color.MAGENTA, "%s: terrain needs a placeholder material" % terrain_id)
		assert_true(material.albedo_texture != null, "%s: placeholder material needs procedural detail" % terrain_id)


func test_runtime_hides_flat_map_visuals_without_disabling_collision() -> void:
	var terrain := Node2D.new()
	var building := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32.0, 32.0)
	collision.shape = shape
	building.add_child(collision)
	var prop := Node2D.new()
	var bootstrap := {
		"assembled": {
			"terrain": terrain,
			"buildings": [building],
			"props": [prop],
		},
	}

	MapViewRuntime._hide_flat_map_visuals(bootstrap)

	assert_false(terrain.visible, "flat terrain must not overlay the 3D view")
	assert_false(building.visible, "flat building art must not overlay the 3D view")
	assert_false(prop.visible, "flat prop art must not overlay the 3D view")
	assert_false(collision.disabled, "hiding flat art must preserve logic-plane collision")
	terrain.free()
	building.free()
	prop.free()


func test_runtime_maps_keyboard_to_screen_axes_and_faces_idle_rig_at_camera() -> void:
	var scene_root := Node2D.new()
	var map_root := Node2D.new()
	var actors := Node2D.new()
	var player := PLAYER_SCENE.instantiate() as Player
	scene_root.add_child(map_root)
	scene_root.add_child(actors)
	actors.add_child(player)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene_root)

	var definition := LowerTownSlice.create()
	var bootstrap := {
		"definition": definition,
		"grid": MapBuilder.build(definition),
		"assembled": {"buildings": [], "props": []},
	}
	var runtime := MapViewRuntime.install(scene_root, bootstrap, map_root, player)
	var screen_up_in_logic := player.movement_direction_for_screen_input(Vector2.UP)
	assert_true(
		screen_up_in_logic.is_equal_approx(Vector2(-1.0, -1.0).normalized()),
		"the fixed camera must project Up to the screen's top edge"
	)

	var rig := runtime.get_node("PlayerRig") as SharedCharacterRig
	var camera := runtime.view.view_camera()
	var camera_offset := camera.position - rig.position
	var camera_direction := Vector2(camera_offset.x, camera_offset.z).normalized()
	assert_true(
		is_equal_approx(rig.rotation.y, atan2(camera_direction.x, camera_direction.y)),
		"an idle player rig must turn toward the gameplay camera"
	)

	var yaw_before := camera.rotation_degrees.y
	runtime.rotate_view_degrees(30.0)
	assert_true(
		is_equal_approx(camera.rotation_degrees.y, wrapf(yaw_before + 30.0, -180.0, 180.0)),
		"rotate_view_degrees must orbit the camera by the requested angle"
	)
	var rotated_up := player.movement_direction_for_screen_input(Vector2.UP)
	assert_false(
		rotated_up.is_equal_approx(screen_up_in_logic),
		"rotating the view must re-project keyboard movement"
	)
	assert_true(
		is_equal_approx(rotated_up.length(), 1.0),
		"re-projected movement must stay normalized"
	)

	var yaw_before_drag := camera.rotation_degrees.y
	var right_press := InputEventMouseButton.new()
	right_press.button_index = MOUSE_BUTTON_RIGHT
	right_press.pressed = true
	runtime._unhandled_input(right_press)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(-100.0, 0.0)
	runtime._unhandled_input(drag)
	assert_true(
		is_equal_approx(
			camera.rotation_degrees.y,
			wrapf(yaw_before_drag + 100.0 * MapViewRuntime.MOUSE_ROTATE_DEGREES_PER_PIXEL, -180.0, 180.0)
		),
		"right-click drag must orbit the camera horizontally"
	)
	var right_release := InputEventMouseButton.new()
	right_release.button_index = MOUSE_BUTTON_RIGHT
	right_release.pressed = false
	runtime._unhandled_input(right_release)

	var default_camera_size := camera.size
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	runtime._unhandled_input(wheel_up)
	assert_true(camera.size < default_camera_size, "mouse wheel up must zoom toward the player")

	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	runtime._unhandled_input(wheel_down)
	assert_true(
		is_equal_approx(camera.size, default_camera_size),
		"opposite wheel steps must restore the previous zoom level"
	)

	runtime.zoom_view_steps(100.0)
	assert_true(
		is_equal_approx(camera.size, MapViewRuntime.ZOOM_MIN_ORTHOGRAPHIC_SIZE),
		"zooming in must stop at the close-up limit"
	)
	runtime.zoom_view_steps(-200.0)
	assert_true(
		is_equal_approx(camera.size, MapViewRuntime.ZOOM_MAX_ORTHOGRAPHIC_SIZE),
		"zooming out must stop at the overview limit"
	)
	scene_root.free()


func test_occlusion_query_flags_actors_behind_masses_only() -> void:
	var definition := LowerTownSlice.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	var toward_camera: Vector3 = view.view_camera().transform.basis.z * MapView3D.CAMERA_DISTANCE
	var away := Vector3(toward_camera.x, 0.0, toward_camera.z).normalized()
	var scale := MapViewBridge.world_scale(definition.cell_size)

	var wall: Dictionary = {}
	for building in definition.buildings:
		if building["id"] == &"city_wall_north":
			wall = building
	assert_false(wall.is_empty(), "Lower Town slice must keep its north wall")
	var footprint: Rect2 = wall["footprint"]
	var center := footprint.get_center() * scale
	var half_depth := footprint.size * scale * 0.5
	var hidden := Vector3(center.x, 0.0, center.y) - away * (maxf(half_depth.x, half_depth.y) + 1.0)
	assert_true(
		view.is_segment_occluded(hidden + Vector3.UP, hidden + Vector3.UP + toward_camera),
		"an actor tucked behind the town wall must read as occluded"
	)

	var world_units := Vector2(definition.size_cells)
	var open := Vector3(world_units.x, 0.0, world_units.y) + away * 4.0
	assert_false(
		view.is_segment_occluded(open + Vector3.UP, open + Vector3.UP + toward_camera),
		"an actor on the camera side of every mass must not read as occluded"
	)
	view.free()


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
	var bridge := arch.get_node("Bridge") as MeshInstance3D
	var bridge_mesh := bridge.mesh as BoxMesh
	assert_true(
		bridge.position.y - bridge_mesh.size.y * 0.5 >= 2.0,
		"the arch must clear the frozen 2.0-unit character"
	)
	arch.free()
