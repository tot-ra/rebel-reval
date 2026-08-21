extends SceneTree

## R-667 / P0-102. Three-tier gameplay evidence on one authored Lower Town route.
## Requires a rendering-capable run (no --headless):
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tools/capture_p0_102_three_tier_gameplay.gd
##
## WHY: source tier counts and generic route plates do not prove that the three
## R-003 ordinary tiers read together at gameplay scale. This helper reuses the
## production map/view pipeline and changes only the evidence camera.

const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const CharacterScale := preload("res://assets/characters/shared/character_scale.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")

const OUTPUT_DIR := "res://docs/reports/images/p0_102_three_tier"
const MANIFEST_PATH := OUTPUT_DIR + "/capture_manifest.json"
const MAP_ID := "lower_town_slice"
const MAP_REVISION := "lower_town_slice.rrmap authored source; record HEAD separately"
const RENDERER := "gl_compatibility"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const ORTHOGRAPHIC_SIZE := CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
const FOCUS_HEIGHT := 0.8
const WARMUP_FRAMES := 12

## This midpoint follows the existing playable checkpoint -> brewery route. The
## broad gameplay crop intentionally includes the stone/timber frontage at the
## north edge and the compact craft row below it without adding map anchors.
const PRESETS: Array[Dictionary] = [
	{
		"id": "three_tier_route",
		"from_anchor": &"checkpoint_west",
		"to_anchor": &"brewery_door",
		"sector_id": "merchant_craft_lane",
		"coverage": "merchant frontage into craft/workshop lane",
		"camera_intent": "three-tier ordinary frontage at gameplay scale",
		"interaction_targets": ["checkpoint_west", "brewery_door"],
		"observed_buildings": [
			"kaik_house_west",
			"viru_house_west",
			"sauna_corner_house",
			"saddlers_rear_workshop",
		],
		"tier_labels": ["merchant_stone", "merchant_timber", "craft_boda"],
		"material_families": ["limestone", "plaster", "log"],
		"roof_families": ["tile", "shingle", "thatch"],
		"exceptional_landmarks": [
			"st_catherines_church",
			"viru_gate_arch",
			"viru_foregate_arch",
		],
		"readability_limitations": (
			"Gameplay crop is route-scale rather than a close-up; roof-cover and wall-family "
			+ "readings remain subject to human visual review."
		),
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition := LowerTownSlice.create()
	if definition.map_id != StringName(MAP_ID) or not definition.active:
		push_error("Unexpected production map for R-667 capture: %s" % definition.map_id)
		quit(1)
		return
	if not _anchors_are_authored(definition):
		quit(1)
		return

	var selection := _capture_selection()
	if selection["error"] != OK:
		quit(selection["error"])
		return
	var manifest := _manifest_header(definition)
	var preset: Dictionary = PRESETS[0]
	var plate_metadata := _preset_metadata(definition, preset)
	for time_of_day in MapView3D.ALL_TIMES:
		if not selection["time_of_day"].is_empty() and String(time_of_day) != selection["time_of_day"]:
			continue
		var result := await _capture(definition, preset, time_of_day, plate_metadata)
		if result["error"] != OK:
			quit(1)
			return
		manifest["plates"].append(result["metadata"])

	var manifest_error := _write_manifest(manifest)
	if manifest_error != OK:
		push_error("Could not save R-667 capture manifest: %s" % error_string(manifest_error))
		quit(1)
		return
	print("R-667 three-tier gameplay evidence written: %s" % OUTPUT_DIR)
	quit(0)


func _capture_selection() -> Dictionary:
	var selection := {"time_of_day": "", "error": OK}
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		var argument := String(args[index])
		if argument == "--time":
			if index + 1 >= args.size():
				push_error("R-667 --time requires day or night")
				selection["error"] = ERR_INVALID_PARAMETER
				return selection
			selection["time_of_day"] = String(args[index + 1])
			index += 2
			continue
		push_error("Unknown R-667 capture argument: %s" % argument)
		selection["error"] = ERR_INVALID_PARAMETER
		return selection
	if not selection["time_of_day"].is_empty() and not ["day", "night"].has(selection["time_of_day"]):
		push_error("R-667 --time must be day or night")
		selection["error"] = ERR_INVALID_PARAMETER
	return selection


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
		push_error("R-667 evidence requires MapView3D's orthographic camera")
		viewport.queue_free()
		await process_frame
		return {"error": ERR_CANT_CREATE}
	_configure_camera(camera, plate_metadata["focus_world"])

	for _frame in WARMUP_FRAMES:
		await process_frame
	var texture := viewport.get_texture()
	if texture == null:
		push_error("R-667 evidence viewport has no texture for %s" % time_of_day)
		viewport.queue_free()
		await process_frame
		return {"error": ERR_CANT_CREATE}

	var image := texture.get_image()
	var output_name := "%s_%s.png" % [preset["id"], time_of_day]
	var output_path := "%s/%s" % [OUTPUT_DIR, output_name]
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Could not save R-667 evidence %s: %s" % [output_path, error_string(error)])
	else:
		print(
			"R-667 three-tier evidence: %s (%dx%d)"
			% [output_path, image.get_width(), image.get_height()]
		)

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
	# Preserve the shipped dimetric pitch/yaw and move along the camera's own
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
		"observed_buildings": preset["observed_buildings"].duplicate(),
		"tier_labels": preset["tier_labels"].duplicate(),
		"material_families": preset["material_families"].duplicate(),
		"roof_families": preset["roof_families"].duplicate(),
		"exceptional_landmarks": preset["exceptional_landmarks"].duplicate(),
		"readability_limitations": String(preset["readability_limitations"]),
		"focus_logic_cell": [focus_logic.x, focus_logic.y],
		"focus_height": FOCUS_HEIGHT,
		"focus_world": MapViewBridge.logic_to_world(focus_logic, definition.cell_size, FOCUS_HEIGHT),
		"orthographic_size": ORTHOGRAPHIC_SIZE,
		"camera_pitch_degrees": MapView3D.CAMERA_PITCH_DEGREES,
		"camera_yaw_degrees": MapView3D.CAMERA_YAW_DEGREES,
	}


func _manifest_header(definition: MapDefinition) -> Dictionary:
	return {
		"schema": "r-667-p0-102-three-tier-gameplay-v1",
		"task": "R-667 / P0-102 decomposition",
		"map_id": String(definition.map_id),
		"map_revision": MAP_REVISION,
		"map_fingerprint": definition.fingerprint,
		"renderer": RENDERER,
		"viewport": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"orthographic_size": ORTHOGRAPHIC_SIZE,
		"times": [String(MapView3D.TIME_DAY), String(MapView3D.TIME_NIGHT)],
		"presets": PRESETS.map(func(preset: Dictionary) -> String: return String(preset["id"])),
		"route_contract": (
			"One matched checkpoint_west -> brewery_door route crop must read all three "
			+ "ordinary R-003 tiers; exceptional landmarks remain excluded from ordinary coverage."
		),
		"command": (
			"Godot --path . --rendering-method gl_compatibility "
			+ "--rendering-driver opengl3 --script tools/capture_p0_102_three_tier_gameplay.gd"
		),
		"plates": [],
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
				push_error("R-667 preset %s references missing anchor %s" % [preset["id"], anchor_id])
				return false
	return true
