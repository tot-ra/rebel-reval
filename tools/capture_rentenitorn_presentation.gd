extends SceneTree

## R-785 / P4-027d presentation evidence.
## Captures the Rentenitorn interior and the north-quarter exterior door through
## the production MapView3D at the gameplay orthographic scale. Day and night
## use identical focus and camera settings so reviewers can compare values without
## mistaking a framing change for a lighting change.
## Requires a rendering-capable run (not --headless):
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tools/capture_rentenitorn_presentation.gd

const RentenitornDefinition := preload(
	"res://scripts/map/definitions/prototypes/rentenitorn_interior_definition.gd"
)
const NorthQuarterDefinition := preload(
	"res://scripts/map/definitions/prototypes/north_quarter_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const CharacterScale := preload("res://assets/characters/shared/character_scale.gd")

const OUTPUT_DIR := "res://docs/reports/images/rentenitorn"
const MANIFEST_PATH := OUTPUT_DIR + "/capture_manifest.json"
const INTERIOR_MAP_ID := "rentenitorn_interior"
const EXTERIOR_MAP_ID := "north_quarter"
const INTERIOR_ENTRY_ID := "rentenitorn_interior_entry"
const EXTERIOR_TOWER_ID := "merchant_wall_tower_northwest"
const EXTERIOR_DOOR_ID := "rentenitorn_enter"
const EXTERIOR_RETURN_SPAWN_ID := "merchant_wall_tower_northwest_return"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 14
const CAMERA_DISTANCE := MapView3D.CAMERA_DISTANCE


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var interior: MapDefinition = RentenitornDefinition.create()
	var exterior: MapDefinition = NorthQuarterDefinition.create()
	if not _validate_sources(interior, exterior):
		quit(1)
		return

	var interior_focus := _interior_focus(interior)
	var exterior_focus := _exterior_focus(exterior, false)
	var exterior_door_focus := _exterior_focus(exterior, true)
	var manifest := {
		"task": "R-785 / P4-027d",
		"renderer": "gl_compatibility",
		"render_driver": "opengl3",
		"viewport_px": [int(VIEWPORT_SIZE.x), int(VIEWPORT_SIZE.y)],
		"camera": {
			"projection": "orthographic",
			"orthographic_size": CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE,
			"pitch_degrees": MapView3D.CAMERA_PITCH_DEGREES,
			"yaw_degrees": MapView3D.CAMERA_YAW_DEGREES,
			"distance": CAMERA_DISTANCE,
		},
		"camera_intent": "gameplay-scale tower presentation",
		"historical_boundary": "pre-mid-14c presence; reversible plan/fabric reconstruction",
		"maps": {
			INTERIOR_MAP_ID: {"fingerprint": interior.fingerprint, "active": interior.active},
			EXTERIOR_MAP_ID: {"fingerprint": exterior.fingerprint, "active": exterior.active},
		},
		"plates": [],
	}

	for time_of_day in MapView3D.ALL_TIMES:
		var interior_result := await _capture(
			interior,
			INTERIOR_MAP_ID,
			[
				INTERIOR_ENTRY_ID,
				"rentenitorn_floor_ground",
				"rentenitorn_floor_watch",
				"rentenitorn_floor_roof",
				"rentenitorn_wall_walk",
			],
			interior_focus,
			time_of_day,
			"rentenitorn_interior",
			"interior three-band route and wall-walk"
		)
		if not _append_capture_result(manifest, interior_result):
			quit(1)
			return

		var exterior_result := await _capture(
			exterior,
			EXTERIOR_MAP_ID,
			[EXTERIOR_TOWER_ID],
			exterior_focus,
			time_of_day,
			"north_quarter_merchant_wall_tower_northwest",
			"exterior tower approach"
		)
		if not _append_capture_result(manifest, exterior_result):
			quit(1)
			return

		var door_result := await _capture(
			exterior,
			EXTERIOR_MAP_ID,
			[EXTERIOR_TOWER_ID, EXTERIOR_DOOR_ID, EXTERIOR_RETURN_SPAWN_ID],
			exterior_door_focus,
			time_of_day,
			"north_quarter_merchant_wall_tower_northwest_door",
			"exterior south door and return spawn"
		)
		if not _append_capture_result(manifest, door_result):
			quit(1)
			return

	var manifest_file := FileAccess.open(
		ProjectSettings.globalize_path(MANIFEST_PATH), FileAccess.WRITE
	)
	if manifest_file == null:
		push_error("Could not write %s" % MANIFEST_PATH)
		quit(1)
		return
	manifest_file.store_string(JSON.stringify(manifest, "  "))
	manifest_file.close()
	print("R-785 Rentenitorn presentation captures written: %s" % OUTPUT_DIR)
	quit(0)


func _validate_sources(interior: MapDefinition, exterior: MapDefinition) -> bool:
	if interior.map_id != StringName(INTERIOR_MAP_ID):
		push_error("Unexpected Rentenitorn map id: %s" % interior.map_id)
		return false
	if exterior.map_id != StringName(EXTERIOR_MAP_ID):
		push_error("Unexpected north-quarter map id: %s" % exterior.map_id)
		return false
	if _find_anchor(interior, StringName(INTERIOR_ENTRY_ID)).is_empty():
		push_error("R-785 interior capture cannot find the entry anchor")
		return false
	var tower := _find_building(exterior, StringName(EXTERIOR_TOWER_ID))
	if tower.is_empty():
		push_error("R-785 exterior capture cannot find %s" % EXTERIOR_TOWER_ID)
		return false
	var door := _find_transition(exterior, StringName(EXTERIOR_DOOR_ID))
	if door.is_empty() or String(door.get("building_id", "")) != EXTERIOR_TOWER_ID:
		push_error("R-785 exterior capture cannot find the Rentenitorn door transition")
		return false
	return true


func _capture(
	definition: MapDefinition,
	map_id: String,
	stable_ids: Array[String],
	focus_logic: Vector2,
	time_of_day: StringName,
	view_id: String,
	camera_intent: String
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "R785_%s_%s" % [view_id, String(time_of_day)]
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)

	var view := MapView3D.create(definition, MapBuilder.build(definition), time_of_day)
	view.activate_all_chunks()
	viewport.add_child(view)
	var sky := view.sky_weather()
	if sky != null:
		sky.auto_weather = false
		sky.set_weather(SkyWeather3D.WEATHER_CLEAR)
		sky.advance(1.0)
	view.set_weather_time_scale(0.0)
	view.set_time_of_day(time_of_day)
	var camera := view.view_camera()
	camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
	var focus_world := MapViewBridge.logic_to_world(focus_logic, definition.cell_size, 0.8)
	camera.global_position = focus_world + camera.global_transform.basis.z * CAMERA_DISTANCE
	camera.look_at(focus_world, Vector3.UP)

	for _frame in WARMUP_FRAMES:
		await process_frame
	var texture := viewport.get_texture()
	if texture == null:
		push_error("R-785 viewport has no texture for %s/%s" % [view_id, time_of_day])
		await _cleanup_view(view, viewport)
		return {"ok": false}
	var image := texture.get_image()
	if image == null or image.get_size() != VIEWPORT_SIZE:
		push_error(
			"R-785 capture dimensions are not %dx%d for %s/%s"
			% [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, view_id, time_of_day]
		)
		await _cleanup_view(view, viewport)
		return {"ok": false}
	var output := "%s/%s_%s.png" % [OUTPUT_DIR, view_id, String(time_of_day)]
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save R-785 plate %s: %s" % [output, error_string(error)])
		await _cleanup_view(view, viewport)
		return {"ok": false}
	print("R-785 Rentenitorn plate: %s (%dx%d)" % [output, image.get_width(), image.get_height()])
	var metadata := {
		"view_id": view_id,
		"map_id": map_id,
		"stable_ids": stable_ids,
		"time_of_day": String(time_of_day),
		"output": output,
		"framing_key": "%s|%.3f|%.3f|%.3f|%.3f" % [
			view_id,
			focus_world.x,
			focus_world.y,
			focus_world.z,
			CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE,
		],
		"focus_logic_px": [focus_logic.x, focus_logic.y],
		"focus_world": [focus_world.x, focus_world.y, focus_world.z],
		"camera_intent": camera_intent,
	}
	await _cleanup_view(view, viewport)
	return {"ok": true, "metadata": metadata}


func _append_capture_result(manifest: Dictionary, result: Dictionary) -> bool:
	if not bool(result.get("ok", false)):
		return false
	manifest["plates"].append(result["metadata"])
	return true


func _cleanup_view(view: MapView3D, viewport: SubViewport) -> void:
	MapView3D._strip_geometry_materials(view)
	viewport.queue_free()
	await process_frame


func _interior_focus(definition: MapDefinition) -> Vector2:
	# The centre keeps all three floor anchors and the west wall-walk in the same
	# gameplay frame without turning the evidence into a top-down debug overview.
	var ground := _find_anchor(definition, StringName("rentenitorn_floor_ground"))
	var wall_walk := _find_anchor(definition, StringName("rentenitorn_wall_walk"))
	return (ground["position"] + wall_walk["position"]) * 0.5


func _exterior_focus(definition: MapDefinition, door_only: bool) -> Vector2:
	var tower := _find_building(definition, StringName(EXTERIOR_TOWER_ID))
	var door := _find_transition(definition, StringName(EXTERIOR_DOOR_ID))
	var tower_center: Vector2 = tower["footprint"].get_center()
	var door_center: Vector2 = door["rect"].get_center()
	return door_center if door_only else (tower_center + door_center) * 0.5


func _find_building(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building.get("id", &"") == building_id:
			return building
	return {}


func _find_anchor(definition: MapDefinition, anchor_id: StringName) -> Dictionary:
	for anchor in definition.interaction_anchors:
		if anchor.get("id", &"") == anchor_id:
			return anchor
	return {}


func _find_transition(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition.get("id", &"") == transition_id:
			return transition
	return {}
