extends Node3D
## Small isolated art-review scene. Does not alter inventory, saves or live maps.
const DIR := "res://assets/characters/kalev_rebuild/"
const OUTFITS: Array[String] = ["Body", "Forge", "Travel", "Mail"]
const MOTIONS: Array[StringName] = [&"idle", &"walk", &"run", &"guard", &"hammer_attack"]
var rig: SharedCharacterRig
var camera: Camera3D
var status: Label
var outfit_index := 1
var weapon_index := 0
var motion_index := 0
var orbit := 0.18
var camera_distance := 3.8
var dragging := false
var panning := false
var aim_height := 1.05
var hud: CanvasLayer

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("20272c")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b9c8d6")
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	add_child(env)
	_light(Vector3(-3, 5, 4), 0.95, Color("fff0df"))
	_light(Vector3(3, 3, -2), 0.45, Color("b7d3ea"))
	var floor_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.2
	cylinder.bottom_radius = 1.2
	cylinder.height = 0.05
	floor_mesh.mesh = cylinder
	floor_mesh.position.y = -0.035
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("343d42")
	mat.roughness = 0.9
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	rig = load(DIR + "kalev_fresh.tscn").instantiate() as SharedCharacterRig
	add_child(rig)
	camera = Camera3D.new()
	camera.fov = 38
	add_child(camera)
	camera.make_current()
	_update_camera()
	_create_hud()
	set_outfit(1)

func _light(at: Vector3, energy: float, color: Color) -> void:
	var light := DirectionalLight3D.new()
	add_child(light)
	light.position = at
	light.look_at(Vector3(0, 1, 0))
	light.light_energy = energy
	light.light_color = color
	light.shadow_enabled = true

func _create_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var panel := VBoxContainer.new()
	panel.position = Vector2(28, 24)
	hud.add_child(panel)
	var title := Label.new()
	title.text = "KALEV  /  FRESH CHARACTER STUDY"
	title.add_theme_font_size_override("font_size", 23)
	panel.add_child(title)
	var detail := Label.new()
	detail.text = "Original sculpt · fitted wardrobe · shared motion rig"
	panel.add_child(detail)
	status = Label.new()
	panel.add_child(status)
	var controls := Label.new()
	controls.text = "1–4  Outfit    W  Weapon    M  Motion\nDrag  Orbit    Right drag  Pan    Wheel  Zoom\nGamepad: A outfit · Y weapon · shoulders motion · sticks orbit/pan · triggers zoom"
	controls.add_theme_color_override("font_color", Color("a6b6c0"))
	panel.add_child(controls)

func set_outfit(index: int) -> void:
	outfit_index = posmod(index, OUTFITS.size())
	for slot: StringName in [&"torso", &"outerwear", &"legs", &"feet"]:
		rig.unequip_wearable(slot)
	if outfit_index > 0:
		var torso := ["", "linen_shirt", "wool_tunic", "mail_shirt"][outfit_index] as String
		for garment: String in [torso, "hose", "boots"]:
			var equipped_ok := rig.equip_wearable(load(DIR + garment + ".tres") as CharacterWearable)
			assert(equipped_ok)
		if outfit_index == 1:
			var apron_ok := rig.equip_wearable(load(DIR + "smith_apron.tres") as CharacterWearable)
			assert(apron_ok)
	_update_status()

func set_weapon(index: int) -> void:
	weapon_index = posmod(index, 3)
	if weapon_index == 0:
		rig.unequip(&"right_hand")
	else:
		var file := "hammer" if weapon_index == 1 else "sword"
		var mounted := rig.equip(&"right_hand", load(DIR + file + ".glb") as PackedScene)
		assert(mounted != null)
	_update_status()

func set_motion(index: int) -> void:
	motion_index = posmod(index, MOTIONS.size())
	rig.play_animation(MOTIONS[motion_index])
	_update_status()

func _update_status() -> void:
	if status != null:
		status.text = "%s  ·  %s  ·  %s" % [OUTFITS[outfit_index], ["Unarmed", "Hammer", "Sword"][weapon_index], MOTIONS[motion_index]]

func _update_camera() -> void:
	camera.position = Vector3(sin(orbit) * camera_distance, aim_height + 0.12, cos(orbit) * camera_distance)
	camera.look_at(Vector3(0, aim_height, 0))

func _process(delta: float) -> void:
	for joy: int in Input.get_connected_joypads():
		var axis := Input.get_joy_axis(joy, JOY_AXIS_LEFT_X)
		if absf(axis) > 0.2:
			orbit += axis * delta * 1.5
			_update_camera()
		var pan := Input.get_joy_axis(joy, JOY_AXIS_RIGHT_Y)
		var zoom := Input.get_joy_axis(joy, JOY_AXIS_TRIGGER_LEFT) - Input.get_joy_axis(joy, JOY_AXIS_TRIGGER_RIGHT)
		if absf(pan) > 0.2 or absf(zoom) > 0.2:
			aim_height = clampf(aim_height - pan * delta * 0.7, 0.1, 2.1)
			camera_distance = clampf(camera_distance + zoom * delta * 1.4, 0.8, 6.0)
			_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			set_outfit(event.keycode - KEY_1)
		elif event.keycode == KEY_W:
			set_weapon(weapon_index + 1)
		elif event.keycode == KEY_M:
			set_motion(motion_index + 1)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		if event.button_index == MOUSE_BUTTON_RIGHT:
			panning = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			camera_distance = clampf(camera_distance + (-0.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.2), 0.8, 6.0)
			_update_camera()
	if event is InputEventMouseMotion and dragging:
		orbit -= event.relative.x * 0.008
		_update_camera()
	if event is InputEventMouseMotion and panning:
		aim_height = clampf(aim_height + event.relative.y * 0.003, 0.1, 2.1)
		_update_camera()
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A: set_outfit(outfit_index + 1)
			JOY_BUTTON_Y: set_weapon(weapon_index + 1)
			JOY_BUTTON_RIGHT_SHOULDER: set_motion(motion_index + 1)
			JOY_BUTTON_LEFT_SHOULDER: set_motion(motion_index - 1)
