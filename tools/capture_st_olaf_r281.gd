extends SceneTree

## R-673 / R-281 acceptance evidence.
## Captures the authored St Olaf landmark from the production MapView3D at the
## gameplay orthographic scale. The same focus and camera contract is used for
## both day and night so a reviewer can compare silhouette and value readability.
## Requires a rendering-capable run (not --headless):
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tools/capture_st_olaf_r281.gd

const MonasteryQuarterDefinition := preload(
	"res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const CharacterScale := preload("res://assets/characters/shared/character_scale.gd")

const OUTPUT_DIR := "res://docs/reports/images/st_olaf_r281"
const MANIFEST_PATH := OUTPUT_DIR + "/capture_manifest.json"
const MAP_ID := "monastery_quarter"
const LANDMARK_ID := "st_olaf_silhouette"
const FRONTAGE_ID := "st_olaf_frontage"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 12


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	if definition.map_id != StringName(MAP_ID):
		push_error("Unexpected map for R-281 capture: %s" % definition.map_id)
		quit(1)
		return
	var building := _building_by_id(definition, StringName(LANDMARK_ID))
	if building.is_empty():
		push_error("R-281 capture cannot find %s" % LANDMARK_ID)
		quit(1)
		return
	if not _has_anchor(definition, StringName(FRONTAGE_ID)):
		push_error("R-281 capture cannot find %s" % FRONTAGE_ID)
		quit(1)
		return

	var manifest := {
		"task": "R-673 / R-281",
		"map_id": MAP_ID,
		"map_fingerprint": definition.fingerprint,
		"stable_ids": [LANDMARK_ID, FRONTAGE_ID],
		"renderer": "gl_compatibility",
		"viewport_px": [int(VIEWPORT_SIZE.x), int(VIEWPORT_SIZE.y)],
		"camera": {
			"projection": "orthographic",
			"orthographic_size": CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE,
			"pitch_degrees": MapView3D.CAMERA_PITCH_DEGREES,
			"yaw_degrees": MapView3D.CAMERA_YAW_DEGREES,
		},
		"camera_intent": "gameplay-scale St Olaf landmark approach",
		"historical_phase": "compact_1343_mass",
		"plates": [],
	}
	var frontage_logic := _anchor_position(definition, StringName(FRONTAGE_ID))
	var focus_logic: Vector2 = (building["footprint"].get_center() + frontage_logic) * 0.5
	var focus_world := MapViewBridge.logic_to_world(focus_logic, definition.cell_size)
	for time_of_day in MapView3D.ALL_TIMES:
		var result := await _capture(definition, focus_world, time_of_day)
		if result["error"] != OK:
			quit(1)
			return
		manifest["plates"].append(result["metadata"])

	var manifest_file := FileAccess.open(
		ProjectSettings.globalize_path(MANIFEST_PATH), FileAccess.WRITE
	)
	if manifest_file == null:
		push_error("Could not write %s" % MANIFEST_PATH)
		quit(1)
		return
	manifest_file.store_string(JSON.stringify(manifest, "  "))
	manifest_file.close()
	print("R-281 St Olaf acceptance capture written: %s" % OUTPUT_DIR)
	quit(0)


func _capture(
	definition: MapDefinition, focus_world: Vector3, time_of_day: StringName
) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, MapBuilder.build(definition), time_of_day)
	view.activate_all_chunks()
	viewport.add_child(view)
	var camera := view.view_camera()
	camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
	camera.global_position = focus_world + camera.global_transform.basis.z * MapView3D.CAMERA_DISTANCE
	camera.look_at(focus_world, Vector3.UP)

	for _frame in WARMUP_FRAMES:
		await process_frame
	var landmark := view.get_node_or_null("Buildings/Building_%s" % LANDMARK_ID)
	if landmark == null:
		push_error("R-281 capture did not stream %s" % LANDMARK_ID)
		MapView3D._strip_geometry_materials(view)
		viewport.queue_free()
		await process_frame
		return {"error": ERR_DOES_NOT_EXIST}
	var image := viewport.get_texture().get_image()
	var output_name := "st_olaf_%s.png" % String(time_of_day)
	var output_path := "%s/%s" % [OUTPUT_DIR, output_name]
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Could not save R-281 plate %s: %s" % [output_path, error_string(error)])
	else:
		print("R-281 St Olaf plate: %s (%dx%d)" % [output_path, image.get_width(), image.get_height()])

	var metadata := {
		"stable_id": LANDMARK_ID,
		"frontage_id": FRONTAGE_ID,
		"time_of_day": String(time_of_day),
		"output": output_path,
		"framing_key": "st_olaf_frontage|%.3f|%.3f|%.3f" % [
			focus_world.x,
			focus_world.y,
			focus_world.z,
		],
		"focus_world": [focus_world.x, focus_world.y, focus_world.z],
		"camera_intent": "gameplay-scale St Olaf landmark approach",
	}
	MapView3D._strip_geometry_materials(view)
	viewport.queue_free()
	await process_frame
	return {"error": error, "metadata": metadata}


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building.get("id", &"") == building_id:
			return building
	return {}


func _anchor_position(definition: MapDefinition, anchor_id: StringName) -> Vector2:
	for anchor in definition.interaction_anchors:
		if anchor.get("id", &"") == anchor_id:
			return anchor["position"]
	return Vector2.ZERO


func _has_anchor(definition: MapDefinition, anchor_id: StringName) -> bool:
	return _anchor_position(definition, anchor_id) != Vector2.ZERO
