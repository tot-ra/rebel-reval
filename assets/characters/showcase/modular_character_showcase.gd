extends Node3D

const HERO := preload("res://assets/characters/kalev/kalev.tscn")
const MART := preload("res://assets/characters/variants/mart.tscn")
const MAIL := preload("res://assets/characters/shared/hero_mail.tres")
const WEAPONS: Array[PackedScene] = [
	preload("res://assets/characters/shared/hammer.tscn"),
	preload("res://assets/characters/shared/sword.tscn"),
	null,
]
var _hero: SharedCharacterRig
var _figures: Array[SharedCharacterRig] = []
var _weapon_index := 0
var _motion_index := 0
var _outfit_button: Button
var _weapon_button: Button
var _motion_button: Button
var _head_button: Button

func _ready() -> void:
	_build_stage()
	for index: int in 3:
		var rig := (MART if index == 2 else HERO).instantiate() as SharedCharacterRig
		add_child(rig)
		rig.position.x = (index - 1) * 1.85
		rig.rotation_degrees.y = -15
		var health := rig.get_node_or_null("HealthRing") as Node3D
		if health != null:
			health.visible = false
		_figures.append(rig)
	_hero = _figures[1]
	_hero.equip_wearable(MAIL)
	_build_controls()
	if "--verify-controls" in OS.get_cmdline_user_args():
		_verify_controls.call_deferred()
	elif "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("161f29")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b4c8dc")
	environment.ambient_light_energy = 0.65
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -30, 0)
	key.light_color = Color("ffe7ca")
	key.light_energy = 1.1
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 135, 0)
	fill.light_color = Color("94bddf")
	fill.light_energy = 0.6
	add_child(fill)
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("222f3a")
	material.roughness = 0.95
	plane.material = material
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.7
	camera.position = Vector3(0, 1.8, 10)
	add_child(camera)
	camera.look_at(Vector3(0, 1.0, 0))
	camera.current = true

func _build_controls() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	layout.offset_left = 36
	layout.offset_top = 28
	layout.offset_right = -36
	layout.add_theme_constant_override("separation", 10)
	canvas.add_child(layout)
	var title := Label.new()
	title.text = "REVAL REBEL  /  HUMAN CHARACTERS"
	title.add_theme_font_size_override("font_size", 26)
	layout.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Work clothes, fitted armor and held weapons · Change the center character below"
	subtitle.modulate = Color("aabccd")
	layout.add_child(subtitle)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	layout.add_child(row)
	_outfit_button = _button(row, "Outfit: mail", _toggle_outfit)
	_weapon_button = _button(row, "Weapon: hammer", _cycle_weapon)
	_motion_button = _button(row, "Motion: idle", _cycle_motion)
	_head_button = _button(row, "Headwear: none", _toggle_headwear)
	_outfit_button.grab_focus()
	var captions: Array[String] = ["KALEV · WORK CLOTHES", "KALEV · CHANGEABLE OUTFIT", "MART · APPRENTICE"]
	for index: int in 3:
		var caption := Label.new()
		caption.text = captions[index]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		canvas.add_child(caption)
		caption.anchor_left = 0.218 + index * 0.282
		caption.anchor_right = caption.anchor_left
		caption.anchor_top = 1.0
		caption.anchor_bottom = 1.0
		caption.offset_left = -240
		caption.offset_right = 240
		caption.offset_top = -70
		caption.offset_bottom = -40

func _toggle_headwear() -> void:
	if _hero.equipped_wearable(&"head") != null:
		_hero.unequip_wearable(&"head")
		_head_button.text = "Headwear: none"
	else:
		_hero.equip_wearable(preload("res://assets/characters/shared/hero_hat_wearable.tres"))
		_head_button.text = "Headwear: cap"

func _unhandled_input(event: InputEvent) -> void:
	# The project overrides ui_left/right with keyboard-only gameplay bindings.
	# Keep D-pad focus local to this developer showcase instead of changing them.
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index not in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			return
		var buttons: Array[Button] = [_outfit_button, _weapon_button, _motion_button, _head_button]
		var current := buttons.find(get_viewport().gui_get_focus_owner())
		var step := 1 if event.button_index == JOY_BUTTON_DPAD_RIGHT else -1
		buttons[posmod(current + step, buttons.size())].grab_focus()
		get_viewport().set_input_as_handled()

func _button(row: HBoxContainer, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(220, 44)
	button.pressed.connect(action)
	row.add_child(button)
	return button

func _toggle_outfit() -> void:
	if _hero.equipped_wearable(&"torso") != null:
		_hero.unequip_wearable(&"torso")
		_outfit_button.text = "Outfit: work clothes"
	else:
		_hero.equip_wearable(MAIL)
		_outfit_button.text = "Outfit: mail"

func _cycle_weapon() -> void:
	_weapon_index = (_weapon_index + 1) % WEAPONS.size()
	if WEAPONS[_weapon_index] == null:
		_hero.unequip(&"right_hand")
	else:
		_hero.equip(&"right_hand", WEAPONS[_weapon_index])
	_weapon_button.text = "Weapon: %s" % ["hammer", "sword", "unarmed"][_weapon_index]

func _cycle_motion() -> void:
	_motion_index = (_motion_index + 1) % 4
	var motion: StringName = [&"idle", &"walk", &"run", &"hammer_attack"][_motion_index]
	if _motion_index == 3:
		motion = [&"hammer_attack", &"sword_attack", &"unarmed_attack"][_weapon_index]
	_hero.play_animation(motion)
	_motion_button.text = "Motion: %s" % motion

func _capture() -> void:
	for rig: SharedCharacterRig in _figures:
		rig.animation_player().seek(0.0, true)
		rig.animation_player().pause()
	for frame: int in 3:
		await get_tree().process_frame
	var path := "res://docs/reports/images/characters/modular_after/showcase.png"
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	get_tree().quit(0 if error == OK else 1)

func _verify_controls() -> void:
	await get_tree().process_frame
	var key := InputEventKey.new()
	_outfit_button.grab_focus()
	key.keycode = KEY_ENTER
	key.physical_keycode = KEY_ENTER
	key.pressed = true
	get_viewport().push_input(key)
	await get_tree().process_frame
	key = key.duplicate() as InputEventKey
	key.pressed = false
	get_viewport().push_input(key)
	await get_tree().process_frame
	if _hero.equipped_wearable(&"torso") != null:
		push_error("Keyboard outfit toggle failed")
		get_tree().quit(1)
		return
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	get_viewport().push_input(pad)
	await get_tree().process_frame
	pad = pad.duplicate() as InputEventJoypadButton
	pad.pressed = false
	get_viewport().push_input(pad)
	await get_tree().process_frame
	if _hero.equipped_wearable(&"torso") == null:
		push_error("Gamepad outfit toggle failed")
		get_tree().quit(1)
		return
	pad = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_RIGHT
	pad.pressed = true
	get_viewport().push_input(pad)
	await get_tree().process_frame
	if not _weapon_button.has_focus():
		push_error("Gamepad focus travel failed")
		get_tree().quit(1)
		return
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = _weapon_button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = mouse.position
	get_viewport().push_input(move, true)
	await get_tree().process_frame
	mouse.pressed = true
	get_viewport().push_input(mouse, true)
	mouse = mouse.duplicate() as InputEventMouseButton
	mouse.pressed = false
	get_viewport().push_input(mouse, true)
	await get_tree().process_frame
	if _weapon_index != 1:
		push_error("Mouse weapon swap failed")
		get_tree().quit(1)
		return
	print("Wardrobe showcase: keyboard, gamepad toggles/focus and mouse weapon swap passed")
	get_tree().quit(0)
