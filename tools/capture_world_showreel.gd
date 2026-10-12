extends Node

## README showreel: short clips of the live seamless Reval scene with real input
## and the gameplay camera. Kalev runs at a town gate and along the shore, the
## same street corner is shown in four seasons, spirit sight is switched on
## among citizens, and the forge fire burns in the smithy.
## Each frame is saved as a PNG; tools/build_world_showreel_gif.sh joins them.
## Run with a fixed frame step so motion plays back at real speed however slow
## the render is:
##   tools/godot_render.sh --resolution 1280x720 --fixed-fps 12 \
##     res://tools/capture_world_showreel.tscn
## Output: build/showreel/<clip>/NNN.png (gitignored scratch).

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const OUTPUT_DIR := "res://build/showreel"
const FRAME_SIZE := Vector2i(960, 540)
const FPS := 12
const SETTLE_FRAMES := 24
## Mid-morning: a lower sun than noon, softer light, no glare off the sea.
const DAY_PROGRESS := 0.42
## Mixed grove of birch, ash and oak north-east of the Viru Gate (plan trees).
const GROVE_VIEW_FROM := Vector2(330.0, 40.0)
const GROVE_CENTRE := Vector2(365.0, -15.0)

var _city: Node
var _caption: Label


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("The showreel needs a real renderer (tools/godot_render.sh)")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_city = SCENE.instantiate()
	get_tree().root.add_child(_city)
	_add_caption_layer()
	await _frames(4)
	var runtime: MapViewRuntime = _city.runtime
	runtime.set_time_of_day(MapView3D.TIME_DAY)
	_set_morning()
	var sky = _city.world.sky_weather
	sky.auto_weather = false
	sky.set_weather(&"clear")
	# Summer first; the season clip runs last because season jumps only go forward.
	runtime.jump_to_season(&"summer")
	var plan: CityPlan = _city.plan
	await _gate_run(plan)
	await _spirit_sight(plan)
	await _shore_run(plan)
	await _forge(plan)
	await _seasons(plan)
	print("showreel: done")
	get_tree().quit(0)


## set_time_of_day stops the clock at noon; move the stopped clock to the morning.
func _set_morning() -> void:
	_city.runtime._environment.cycle_progress = DAY_PROGRESS
	_city.view.apply_cycle_progress(DAY_PROGRESS)


func _add_caption_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	get_tree().root.add_child(layer)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.075, 0.06, 0.82)
	style.set_content_margin_all(10.0)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -28.0
	layer.add_child(panel)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 42)
	_caption.add_theme_color_override("font_color", Color("#fff4d6"))
	panel.add_child(_caption)


## Turns the gameplay camera to look along `direction` (plan XZ), the same way
## the city faces Kalev toward a door on arrival.
func _face(direction: Vector2) -> void:
	var camera: Camera3D = _city.view.view_camera()
	var yaw := rad_to_deg(atan2(-direction.x, -direction.y))
	_city.runtime._camera_controller.rotate_view_degrees(yaw - camera.rotation_degrees.y)


func _steer(direction: Vector2) -> void:
	var player: Player = _city.player
	player.set_screen_movement_basis(Vector2(-direction.y, direction.x), -direction)


func _place(at: Vector2, facing: Vector2) -> void:
	var player: Player = _city.player
	player.global_position = CityPlan.to_logic(at)
	player.velocity = Vector2.ZERO
	_steer(facing)
	_face(facing)
	await _frames(SETTLE_FRAMES)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## Records `seconds` of play into build/showreel/<clip>/. While `run` is set,
## Kalev runs along `direction` (default movement is a run; Shift walks).
func _record(clip: String, caption: String, seconds: float, direction := Vector2.ZERO) -> void:
	var dir := "%s/%s" % [OUTPUT_DIR, clip]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_caption.text = caption
	var count := int(seconds * FPS)
	var running := not direction.is_zero_approx()
	if running:
		Input.action_press(&"ui_up")
	for i in count:
		if running:
			_steer(direction)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_tree().root.get_viewport().get_texture().get_image()
		image.resize(FRAME_SIZE.x, FRAME_SIZE.y, Image.INTERPOLATE_BILINEAR)
		image.save_png(ProjectSettings.globalize_path("%s/%03d.png" % [dir, i]))
	if running:
		Input.action_release(&"ui_up")
	print("showreel: %s (%d frames)" % [clip, count])


func _gate_at(plan: CityPlan, id: String) -> Dictionary:
	var g := plan.gate(id)
	var at := Vector2(g["at"][0], g["at"][1])
	var inside := CityTravel.spawn_position(plan, id)
	return {"at": at, "inward": (inside - at).normalized()}


## Kalev runs from Viru street out through the Viru Gate toward the fields.
func _gate_run(plan: CityPlan) -> void:
	var gate := _gate_at(plan, "gate.viru")
	var out: Vector2 = -gate["inward"]
	await _place(gate["at"] + gate["inward"] * 34.0, out)
	await _record("01_gate", "Kalev runs out through the Viru Gate", 4.0, out)


## Spirit sight switches on among the citizens of the market square.
func _spirit_sight(plan: CityPlan) -> void:
	var forum := Vector2(plan.point_of_interest("poi.forum")["at"][0], plan.point_of_interest("poi.forum")["at"][1])
	await _place(forum, Vector2(0.0, -1.0))
	await _record("02_square", "Town Hall square, midday", 1.5)
	var sight: Node = _city.player.get_node("SpiritSight")
	sight.call("toggle")
	await _record("03_sight", "Spirit sight: the souls of the town", 3.0)
	sight.call("leave_immediately")
	await _frames(SETTLE_FRAMES)


## Along the shingle by the fish landing, the Baltic to one side.
func _shore_run(plan: CityPlan) -> void:
	var landing := plan.point_of_interest("poi.fish_landing")
	var at := Vector2(landing["at"][0], landing["at"][1])
	# West along the beach: the sea on the right, the town and its wall on the left.
	var along := Vector2(-1.0, 0.12).normalized()
	await _place(at, along)
	await _record("04_sea", "The shore and the open sea", 3.5, along)


## Kalev's forge bay: hearth, bellows and anvil.
func _forge(plan: CityPlan) -> void:
	var inside := CityTravel.site_spawn(plan, "kalev_smithy")
	if inside.is_empty():
		push_warning("showreel: no kalev_smithy spawn")
		return
	_city.arrive_at("kalev_smithy")
	# Turn a little off the hearth so the frame keeps to the forge bay itself.
	_city.runtime._camera_controller.rotate_view_degrees(-35.0)
	await _frames(SETTLE_FRAMES)
	await _record("05_forge", "Kalev's forge", 2.5)


## One grove outside the Viru Gate through the year: summer, autumn, winter
## (with snowfall), spring.
func _seasons(_plan: CityPlan) -> void:
	var runtime: MapViewRuntime = _city.runtime
	var sky = _city.world.sky_weather
	var index := 0
	for season: StringName in [&"summer", &"autumn", &"winter", &"spring"]:
		if season != &"summer":
			runtime.jump_to_season(season)
		sky.set_weather(&"rain" if season == &"winter" else &"clear")
		_set_morning()
		await _place(GROVE_VIEW_FROM, (GROVE_CENTRE - GROVE_VIEW_FROM).normalized())
		await _frames(SETTLE_FRAMES)
		index += 1
		await _record("06_season_%d_%s" % [index, season], "The grove by the Viru Gate: %s" % season, 1.5)
