extends SceneTree

## R-560 / P0-101f. Deterministic gameplay-scale Lower Town route evidence.
## Requires a rendering-capable run (no --headless):
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tools/capture_lower_town_p0_101.gd
##
## WHY: the P0-101 matrix needs matched day/night route plates, not the existing
## whole-map orthographic smoke image. Each preset is an authored segment between
## production anchors. The camera is the shipped gameplay orthographic size, while
## only the evidence pose is changed; map geometry and runtime systems remain
## authoritative.

const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const CharacterScale := preload("res://assets/characters/shared/character_scale.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")

const OUTPUT_DIR := "res://docs/reports/images/lower_town_p0_101"
const MANIFEST_PATH := OUTPUT_DIR + "/capture_manifest.json"
const MAP_ID := "lower_town_slice"
const MAP_REVISION := "lower_town_slice.rrmap authored source (shared worktree; record HEAD separately)"
const RENDERER := "gl_compatibility"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const ORTHOGRAPHIC_SIZE := CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
const FOCUS_HEIGHT := 0.8
const WARMUP_FRAMES := 12

## One stable crop per required Lower Town sector. Every focus is the midpoint
## of authored anchors, so the packet exercises the production map without adding
## evidence-only camera anchors to the map source.
const PRESETS: Array[Dictionary] = [
	{
		"id": "market_primary_spine",
		"from_anchor": &"vene_street_north",
		"to_anchor": &"checkpoint_west",
		"sector_id": "market_primary_spine",
		"coverage": "market reserve and western primary-spine approach",
		"camera_intent": "market and primary spine readability",
		"interaction_targets": ["vene_street_north", "checkpoint_west"],
	},
	{
		"id": "merchant_craft_lane",
		"from_anchor": &"checkpoint_west",
		"to_anchor": &"brewery_door",
		"sector_id": "merchant_craft_lane",
		"coverage": "merchant frontage into craft/workshop lane",
		"camera_intent": "route-scale merchant and craft frontage",
		"interaction_targets": ["checkpoint_west", "brewery_door"],
	},
	{
		"id": "service_yard",
		"from_anchor": &"brewery_door",
		"to_anchor": &"smithy_door",
		"sector_id": "service_yard",
		"coverage": "brewery and smithy working yards",
		"camera_intent": "route-scale service yard and production frontage",
		"interaction_targets": ["brewery_door", "smithy_door"],
	},
	{
		"id": "eastern_artisan_wet_margin",
		"from_anchor": &"checkpoint_east",
		"to_anchor": &"karja_gate_south",
		"sector_id": "eastern_artisan_wet_margin",
		"coverage": "eastern artisan edge, rear lanes, and southern wet-margin transition",
		"camera_intent": "artisan edge and wet-margin surface readability",
		"interaction_targets": ["checkpoint_east", "karja_gate_south"],
	},
	{
		"id": "landmark_approaches",
		"from_anchor": &"checkpoint_west",
		"to_anchor": &"checkpoint_east",
		"sector_id": "landmark_approaches",
		"coverage": "inner Viru Gate and foregate approach sequence",
		"camera_intent": "landmark approach and gate opening",
		"interaction_targets": ["checkpoint_west", "checkpoint_east"],
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition := LowerTownSlice.create()
	if definition.map_id != StringName(MAP_ID) or not definition.active:
		push_error("Unexpected production map for P0-101 capture: %s" % definition.map_id)
		quit(1)
		return
	if not _anchors_are_authored(definition):
		quit(1)
		return

	var selection := _capture_selection()
	if selection["error"] != OK:
		quit(selection["error"])
		return
	var manifest := _load_manifest(definition, selection["reset_manifest"])
	for preset: Dictionary in PRESETS:
		if not _selection_matches(preset, selection):
			continue
		var plate_metadata := _preset_metadata(definition, preset)
		for time_of_day in MapView3D.ALL_TIMES:
			if not selection["time_of_day"].is_empty() and String(time_of_day) != selection["time_of_day"]:
				continue
			var result := await _capture(definition, preset, time_of_day, plate_metadata)
			if result["error"] != OK:
				quit(1)
				return
			_upsert_plate(manifest, result["metadata"])

	var manifest_error := _write_manifest(manifest)
	if manifest_error != OK:
		push_error("Could not save P0-101 capture manifest: %s" % error_string(manifest_error))
		quit(1)
		return
	print("P0-101 Lower Town route evidence written: %s" % OUTPUT_DIR)
	quit(0)


func _capture_selection() -> Dictionary:
	var selection := {
		"preset_id": "",
		"time_of_day": "",
		"reset_manifest": true,
		"error": OK,
	}
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		var argument := String(args[index])
		if argument == "--preset":
			if index + 1 >= args.size():
				push_error("P0-101 --preset requires a preset ID")
				selection["error"] = ERR_INVALID_PARAMETER
				return selection
			selection["preset_id"] = String(args[index + 1])
			index += 2
			continue
		if argument == "--time":
			if index + 1 >= args.size():
				push_error("P0-101 --time requires day or night")
				selection["error"] = ERR_INVALID_PARAMETER
				return selection
			selection["time_of_day"] = String(args[index + 1])
			index += 2
			continue
		if argument == "--append-manifest":
			selection["reset_manifest"] = false
			index += 1
			continue
		push_error("Unknown P0-101 capture argument: %s" % argument)
		selection["error"] = ERR_INVALID_PARAMETER
		return selection
	if selection["preset_id"].is_empty() and not selection["time_of_day"].is_empty():
		push_error("P0-101 --time requires --preset")
		selection["error"] = ERR_INVALID_PARAMETER
		return selection
	if not selection["time_of_day"].is_empty() and not ["day", "night"].has(selection["time_of_day"]):
		push_error("P0-101 --time must be day or night")
		selection["error"] = ERR_INVALID_PARAMETER
	return selection


func _selection_matches(preset: Dictionary, selection: Dictionary) -> bool:
	return selection["preset_id"].is_empty() or String(preset["id"]) == selection["preset_id"]


func _load_manifest(definition: MapDefinition, reset_manifest: bool) -> Dictionary:
	if not reset_manifest and FileAccess.file_exists(ProjectSettings.globalize_path(MANIFEST_PATH)):
		var existing_variant: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(ProjectSettings.globalize_path(MANIFEST_PATH))
		)
		if existing_variant is Dictionary and existing_variant.get("map_fingerprint", "") == definition.fingerprint:
			return existing_variant
	var manifest := _manifest_header(definition)
	manifest["plates"] = []
	return manifest


func _upsert_plate(manifest: Dictionary, metadata: Dictionary) -> void:
	var plates: Array = manifest.get("plates", [])
	for index in range(plates.size() - 1, -1, -1):
		var existing: Dictionary = plates[index]
		if existing.get("preset_id", "") == metadata["preset_id"] and existing.get("time_of_day", "") == metadata["time_of_day"]:
			plates.remove_at(index)
	plates.append(metadata)
	manifest["plates"] = plates


func _capture(
	definition: MapDefinition,
	preset: Dictionary,
	time_of_day: StringName,
	plate_metadata: Dictionary
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, MapBuilder.build(definition), time_of_day)
	viewport.add_child(view)
	var camera := view.view_camera()
	if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		push_error("P0-101 route evidence requires MapView3D's orthographic camera")
		viewport.queue_free()
		await process_frame
		return {"error": ERR_CANT_CREATE}
	_configure_camera(camera, plate_metadata["focus_world"])

	for _frame in WARMUP_FRAMES:
		await process_frame
	var texture := viewport.get_texture()
	if texture == null:
		push_error("P0-101 evidence viewport has no texture for %s/%s" % [preset["id"], time_of_day])
		viewport.queue_free()
		await process_frame
		return {"error": ERR_CANT_CREATE}

	var image := texture.get_image()
	var output_name := "%s_%s.png" % [preset["id"], time_of_day]
	var output_path := "%s/%s" % [OUTPUT_DIR, output_name]
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Could not save P0-101 evidence %s: %s" % [output_path, error_string(error)])
	else:
		print("P0-101 route evidence: %s (%dx%d)" % [output_path, image.get_width(), image.get_height()])

	var metadata := plate_metadata.duplicate(true)
	metadata["time_of_day"] = String(time_of_day)
	metadata["output"] = output_path
	var focus_world: Vector3 = metadata["focus_world"]
	metadata["focus_world"] = [focus_world.x, focus_world.y, focus_world.z]
	metadata["framing_key"] = "%s|%s|%s|%.3f|%.3f|%.3f" % [
		plate_metadata["preset_id"],
		plate_metadata["focus_logic_cell"],
		plate_metadata["focus_height"],
		plate_metadata["orthographic_size"],
		plate_metadata["camera_pitch_degrees"],
		plate_metadata["camera_yaw_degrees"],
	]
	viewport.queue_free()
	await process_frame
	return {"error": error, "metadata": metadata}


func _configure_camera(camera: Camera3D, focus_world: Vector3) -> void:
	camera.size = ORTHOGRAPHIC_SIZE
	# Preserve the authored dimetric pitch/yaw and move along the camera's own
	# viewing axis; an XZ offset would shift an orthographic crop off the route.
	camera.global_position = focus_world + camera.global_transform.basis.z * MapView3D.CAMERA_DISTANCE
	camera.look_at(focus_world, Vector3.UP)


static func _preset_metadata(definition: MapDefinition, preset: Dictionary) -> Dictionary:
	var from_anchor: StringName = preset["from_anchor"]
	var to_anchor: StringName = preset["to_anchor"]
	var from_position := MapVerification.anchor_position(definition, from_anchor)
	var to_position := MapVerification.anchor_position(definition, to_anchor)
	var focus_logic := (from_position + to_position) * 0.5
	return {
		"preset_id": String(preset["id"]),
		"sector_id": String(preset["sector_id"]),
		"coverage": String(preset["coverage"]),
		"from_anchor": String(from_anchor),
		"to_anchor": String(to_anchor),
		"camera_intent": String(preset["camera_intent"]),
		"interaction_targets": preset["interaction_targets"].duplicate(),
		"focus_logic_cell": [focus_logic.x, focus_logic.y],
		"focus_height": FOCUS_HEIGHT,
		"focus_world": MapViewBridge.logic_to_world(focus_logic, definition.cell_size, FOCUS_HEIGHT),
		"orthographic_size": ORTHOGRAPHIC_SIZE,
		"camera_pitch_degrees": MapView3D.CAMERA_PITCH_DEGREES,
		"camera_yaw_degrees": MapView3D.CAMERA_YAW_DEGREES,
	}


func _manifest_header(definition: MapDefinition) -> Dictionary:
	return {
		"schema": "r-560-lower-town-p0-101-capture-v1",
		"task": "R-560 / P0-101f",
		"map_id": String(definition.map_id),
		"map_revision": MAP_REVISION,
		"map_fingerprint": definition.fingerprint,
		"renderer": RENDERER,
		"viewport": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"orthographic_size": ORTHOGRAPHIC_SIZE,
		"times": [String(MapView3D.TIME_DAY), String(MapView3D.TIME_NIGHT)],
		"presets": PRESETS.map(func(preset: Dictionary) -> String: return String(preset["id"])),
		"command": (
			"Godot --path . --rendering-method gl_compatibility "
			+ "--rendering-driver opengl3 --script tools/capture_lower_town_p0_101.gd"
		),
	}


func _write_manifest(manifest: Dictionary) -> Error:
	var file := FileAccess.open(ProjectSettings.globalize_path(MANIFEST_PATH), FileAccess.WRITE)
	if file == null:
		push_error("Could not open %s for writing" % MANIFEST_PATH)
		return ERR_FILE_CANT_OPEN
	file.store_string(JSON.stringify(manifest, "  "))
	file.close()
	return OK


func _anchors_are_authored(definition: MapDefinition) -> bool:
	for preset: Dictionary in PRESETS:
		for key in [&"from_anchor", &"to_anchor"]:
			var anchor_id: StringName = preset[key]
			if not MapVerification.has_anchor(definition, anchor_id):
				push_error("P0-101 preset %s references missing anchor %s" % [preset["id"], anchor_id])
				return false
	return true
