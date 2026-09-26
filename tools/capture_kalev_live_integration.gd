extends SceneTree

## Deterministic P0-215 evidence using the production Lower Town definition and
## the stable Kalev scene loaded by MapViewRuntime.

const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")
const CharacterScale := preload("res://assets/characters/shared/character_scale.gd")
const LIVE_KALEV := preload("res://assets/characters/kalev/kalev.tscn")
const LIVE_HAMMER := preload("res://assets/storybook/equipment/hammer.tscn")

const OUTPUT_DIR := "res://docs/reports/images/kalev_live_integration"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 16


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition := LowerTownSlice.create()
	if (
		not MapVerification.has_anchor(definition, &"checkpoint_west")
		or not MapVerification.has_anchor(definition, &"brewery_door")
	):
		push_error("Lower Town is missing a production craft-lane anchor")
		quit(1)
		return
	var craft_lane_logic := (
		MapVerification.anchor_position(definition, &"checkpoint_west")
		+ MapVerification.anchor_position(definition, &"brewery_door")
	) * 0.5

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, MapBuilder.build(definition), &"day")
	viewport.add_child(view)
	var rig := LIVE_KALEV.instantiate() as SharedCharacterRig
	view.add_child(rig)
	rig.position = MapViewBridge.logic_to_world(craft_lane_logic, definition.cell_size, 0.03)
	rig.set_facing(Vector2(0.7, 1.0).normalized())
	rig.play_animation(&"idle", 0.0)
	var hammer := rig.equip(&"right_hand", LIVE_HAMMER)
	if rig.body_basename() != "kalev" or hammer == null:
		push_error("Stable Kalev scene did not provide the realistic body and live weapon socket")
		quit(1)
		return

	var camera := view.view_camera()
	var focus := rig.position + Vector3.UP * 0.9
	_configure_camera(camera, focus, CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE)
	if not await _save(viewport, "lower_town_gameplay.png"):
		quit(1)
		return

	_configure_camera(camera, focus, 4.6)
	if not await _save(viewport, "lower_town_closeup.png"):
		quit(1)
		return

	print("CAPTURED stable live Kalev in production Lower Town")
	quit(0)


func _configure_camera(camera: Camera3D, focus: Vector3, orthographic_size: float) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = orthographic_size
	camera.position = focus + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
	camera.look_at(focus, Vector3.UP)
	camera.current = true


func _save(viewport: SubViewport, filename: String) -> bool:
	for _frame: int in WARMUP_FRAMES:
		await process_frame
	var image := viewport.get_texture().get_image()
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + filename)
	var result := image.save_png(output)
	if result != OK:
		push_error("Could not save live Kalev capture: %s" % error_string(result))
		return false
	print("CAPTURED %s" % output)
	return true
