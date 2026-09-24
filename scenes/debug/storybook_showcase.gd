extends Node3D
## P0-203: isolated animated model review, without map or gameplay dependencies.

const HUMANS: Array[String] = ["mart", "aita", "ellen", "watchman", "henning", "jurgen", "kaja"]
const BIRDS: Array[String] = ["robin", "hooded_crow", "gull", "hen", "duck"]
const IDS: Array[String] = ["mart", "aita", "ellen", "watchman", "henning", "jurgen", "kaja", "forge_cat", "sheep", "dog", "pig", "goat", "boar", "fox", "hare", "rat", "robin", "hooded_crow", "gull", "hen", "duck"]
const TITLES: Array[String] = ["Mart", "Aita", "Ellen", "Watchman", "Henning", "Jurgen", "Kaja", "Forge cat", "Sheep", "Dog", "Pig", "Goat", "Boar", "Fox", "Hare", "Rat", "Robin", "Hooded crow", "Gull", "Hen", "Duck"]
const DISPLAY_SCALES: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 2.1, 2.1, 1.3, 1.3, 1.3, 1.3]
var _players: Array[AnimationPlayer] = []
var _models: Array[Node3D] = []
var _subject: OptionButton
var _clips: OptionButton
var _camera: Camera3D
var _paused: bool = false
var _focus: bool = false
var _yaw: float = 0.20
var _pitch: float = 0.43
var _distance: float = 21.0
var _status: Label
var _demo_time: float = 0.0
var _demo_group: int = -1
var _labels: Array[Label3D] = []
var _armor: OptionButton
var _weapon: OptionButton
var _helmet: CheckButton
var _cape: CheckButton
var _shield: CheckButton
var _flight_time: float = -1.0
var _flight_stage: int = -1
var _flight_origins: Dictionary = {}
var _category: int = 0
var _category_picker: OptionButton

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("485565"))
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("485565")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d2dfeb")
	environment.ambient_light_energy = 0.25
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -35, 0)
	key.light_color = Color("ffe0b4")
	key.light_energy = 0.18
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 130, 0)
	fill.light_color = Color("b6d3f1")
	fill.light_energy = 0.08
	add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("485565")
	mat.roughness = 1.0
	ground.material_override = mat
	ground.position.y = -0.04
	add_child(ground)
	_camera = Camera3D.new()
	_camera.fov = 38
	add_child(_camera)
	for i: int in IDS.size():
		var extension := "tscn" if IDS[i] in HUMANS else "glb"
		var packed := load("res://assets/storybook/%s/%s.%s" % [IDS[i], IDS[i], extension]) as PackedScene
		var model := packed.instantiate() as Node3D
		model.position = Vector3((i % 6 - 2.5) * 1.85, 0, (i / 6 - 1.5) * 2.1)
		model.scale = Vector3.ONE * DISPLAY_SCALES[i]
		add_child(model)
		_models.append(model)
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_players.append(player)
		for clip: StringName in player.get_animation_list():
			if clip != &"RESET":
				player.get_animation(clip).loop_mode = Animation.LOOP_NONE if clip in [&"TakeOff", &"Land"] else Animation.LOOP_LINEAR
		player.play(&"Idle")
		var label := Label3D.new()
		label.text = TITLES[i]
		label.font_size = 32
		label.pixel_size = 0.004
		label.position = model.position + Vector3(0, 0.05, 0.8)
		label.rotation_degrees.x = -65
		label.modulate = Color("c2ccd7")
		label.outline_size = 0
		add_child(label)
		_labels.append(label)
	_build_ui()
	_update_camera()
	var args := OS.get_cmdline_user_args()
	if "--clean" in args:
		for layer: Node in get_children():
			if layer is CanvasLayer:
				layer.visible = false
	if "--flight-demo" in args:
		_set_category(3)
		_start_flight()
	if "--equipment-demo" in args or "--capture-equipment" in args:
		_set_category(1)
		_dress_all()
	if "--capture-animals" in args:
		_set_category(2)
	if "--capture-people" in args:
		_set_category(1)
	if "--skirt-demo" in args:
		_set_category(1)
		_subject.select(IDS.find("ellen"))
		_select_subject(_subject.selected)
		for i: int in IDS.size():
			_models[i].visible = i == _subject.selected
			_labels[i].visible = false
		_focus = true
		_distance = 3.8
		_yaw = 0.45
		_update_camera()
	if "--cases-demo" in args:
		_apply_case(0)
	if "--capture-flight" in args:
		_set_category(3)
		_play_group(3)
		for i: int in IDS.size():
			if IDS[i] in BIRDS:
				_players[i].advance(0.30)
				_players[i].speed_scale = 0
	if "--capture" in args or "--capture-equipment" in args or "--capture-flight" in args or "--capture-people" in args or "--capture-animals" in args:
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var plate := "godot_equipment" if "--capture-equipment" in args else ("godot_flight" if "--capture-flight" in args else ("godot_people" if "--capture-people" in args else ("godot_animals" if "--capture-animals" in args else "godot_lineup")))
		get_viewport().get_texture().get_image().save_png("res://docs/reports/images/storybook/%s.png" % plate)
		get_tree().quit()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 20)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var title := Label.new()
	title.text = "REVAL REBEL  /  Grounded character studies"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "22 models · adult proportions · articulated animals · drag to orbit"
	column.add_child(subtitle)
	var category := OptionButton.new()
	_category_picker = category
	for label: String in ["Everyone", "People", "Animals", "Birds"]:
		category.add_item(label)
	column.add_child(category)
	category.item_selected.connect(_set_category)
	var cases := OptionButton.new()
	for label: String in ["Case: civilian idle", "Case: forge work", "Case: travel", "Case: sword and shield", "Case: animal grazing", "Case: animal alert"]:
		cases.add_item(label)
	cases.item_selected.connect(_apply_case)
	column.add_child(cases)
	var row := HBoxContainer.new()
	column.add_child(row)
	_subject = OptionButton.new()
	for label: String in TITLES:
		_subject.add_item(label)
	row.add_child(_subject)
	_subject.item_selected.connect(_select_subject)
	_clips = OptionButton.new()
	row.add_child(_clips)
	_clips.item_selected.connect(_select_clip)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	for entry: Array in [["Idle [1]", 0], ["Move [2]", 1], ["Gesture [3]", 2], ["Run / fly [4]", 3]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(_play_group.bind(entry[1]))
		actions.add_child(button)
	var pause := Button.new()
	pause.text = "Pause / resume"
	pause.pressed.connect(_toggle_pause)
	actions.add_child(pause)
	var focus := Button.new()
	focus.text = "Focus / lineup"
	focus.pressed.connect(func() -> void:
		_focus = not _focus
		_distance = 4.8 if _focus else (21.0 if _category == 0 else 12.0)
		_update_camera())
	actions.add_child(focus)
	var gear := HBoxContainer.new()
	column.add_child(gear)
	_armor = OptionButton.new()
	_armor.add_item("Work clothes")
	_armor.add_item("Mail armour")
	_armor.item_selected.connect(_set_armor)
	gear.add_child(_armor)
	_weapon = OptionButton.new()
	for item: String in ["Empty hand", "Hammer", "Sword"]:
		_weapon.add_item(item)
	_weapon.item_selected.connect(_set_weapon)
	gear.add_child(_weapon)
	_helmet = CheckButton.new()
	_helmet.text = "Helmet"
	_helmet.toggled.connect(_set_wearable.bind("helmet", "head"))
	gear.add_child(_helmet)
	_cape = CheckButton.new()
	_cape.text = "Cape"
	_cape.toggled.connect(_set_wearable.bind("cape", "back"))
	gear.add_child(_cape)
	_shield = CheckButton.new()
	_shield.text = "Shield"
	_shield.toggled.connect(_set_shield)
	gear.add_child(_shield)
	var flight := Button.new()
	flight.text = "Take off → fly → glide → land"
	flight.pressed.connect(_start_flight)
	column.add_child(flight)
	_status = Label.new()
	column.add_child(_status)
	_select_subject(0)
	_subject.grab_focus()

func _select_subject(_index: int) -> void:
	if not _models[_subject.selected].visible:
		_set_category(0)
	_clips.clear()
	var player := _players[_subject.selected]
	for clip: StringName in player.get_animation_list():
		if clip != &"RESET":
			_clips.add_item(String(clip))
			if clip == player.current_animation:
				_clips.select(_clips.item_count - 1)
	_status.text = "%s · %d clips · display scales adjusted for comparison" % [TITLES[_subject.selected], _clips.item_count]
	var human := IDS[_subject.selected] in HUMANS
	for control: BaseButton in [_armor, _weapon, _helmet, _cape, _shield]:
		control.disabled = not human
	if human:
		var rig := _models[_subject.selected] as SharedCharacterRig
		_armor.select(1 if rig.equipped_wearable(&"torso") != null else 0)
		_helmet.set_pressed_no_signal(rig.equipped_wearable(&"head") != null)
		_cape.set_pressed_no_signal(rig.equipped_wearable(&"back") != null)
		_shield.set_pressed_no_signal(rig.equipped(&"left_hand") != null)
		var held := rig.equipped(&"right_hand")
		_weapon.select(0 if held == null else (2 if held.name == &"sword" else 1))
	_update_camera()

func _select_clip(index: int) -> void:
	_stop_flight()
	_players[_subject.selected].play(_clips.get_item_text(index))

func _play_group(group: int) -> void:
	_stop_flight()
	for i: int in IDS.size():
		var choices: Array[String] = []
		if IDS[i] in HUMANS:
			choices.assign(["Idle", "Walking_A", "Interact", "Running_B"])
		elif IDS[i] not in BIRDS:
			choices.assign(["Idle", "Walk", "LookAround", "Run"])
		else:
			choices.assign(["Idle", "Hop", "Peck", "Fly"])
		_players[i].play(choices[group])
	_select_subject(_subject.selected)

func _toggle_pause() -> void:
	_paused = not _paused
	for player: AnimationPlayer in _players:
		player.speed_scale = 0.0 if _paused else 1.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch + event.relative.y * 0.005, 0.08, 1.2)
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(1.7, _distance * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(30.0, _distance * 1.1)
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			_play_group(event.keycode - KEY_1)
		elif event.keycode == KEY_SPACE:
			_toggle_pause()

func _update_camera() -> void:
	var target := Vector3(0 if "--clean" in OS.get_cmdline_user_args() else -0.85, 1.1, 0)
	if _focus and not _models.is_empty():
		target = _models[_subject.selected].position + Vector3(0, 0.9, 0)
	_camera.position = target + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	_camera.look_at(target)

func _process(delta: float) -> void:
	if _paused:
		return
	if _flight_time >= 0:
		_advance_flight(delta)
	if "--skirt-demo" in OS.get_cmdline_user_args():
		_demo_time += delta
		var skirt_group := mini(int(_demo_time / 3.0), 2)
		if skirt_group != _demo_group:
			_demo_group = skirt_group
			var motions: Array[String] = ["Walking_A", "Running_B", "1H_Melee_Attack_Slice_Diagonal"]
			_players[_subject.selected].play(motions[skirt_group])
		return
	if "--cases-demo" in OS.get_cmdline_user_args():
		_demo_time += delta
		var case_index := mini(int(_demo_time / 2.0), 5)
		if case_index != _demo_group:
			_demo_group = case_index
			_apply_case(case_index)
		return
	if "--demo" not in OS.get_cmdline_user_args() and "--equipment-demo" not in OS.get_cmdline_user_args():
		return
	_demo_time += delta
	var group := mini(int(_demo_time / 2.0), 3)
	if group != _demo_group:
		_demo_group = group
		_play_group(group)

func _set_category(category: int) -> void:
	_stop_flight()
	_category = category
	_category_picker.select(category)
	var visible_indices: Array[int] = []
	for i: int in IDS.size():
		var show := category == 0 or (category == 1 and IDS[i] in HUMANS) or (category == 2 and IDS[i] not in HUMANS and IDS[i] not in BIRDS) or (category == 3 and IDS[i] in BIRDS)
		_models[i].visible = show
		_labels[i].visible = show
		if show:
			visible_indices.append(i)
	var columns := 6 if category == 0 else (4 if category == 1 else mini(5, visible_indices.size()))
	var rows := ceili(float(visible_indices.size()) / columns)
	for j: int in visible_indices.size():
		var i := visible_indices[j]
		var row := j / columns
		_models[i].position = Vector3((j % columns - (columns-1)*0.5) * 2.15, 0, (row - (rows - 1) * 0.5) * 2.1)
		_labels[i].position = _models[i].position + Vector3(0, 0.05, 0.8)
	if not visible_indices.has(_subject.selected):
		_subject.select(visible_indices[0])
		_select_subject(visible_indices[0])
	_focus = false
	_distance = 21.0 if category == 0 else (12.0 if category == 1 else 14.0)
	_update_camera()

func _set_armor(index: int) -> void:
	_set_wearable(index == 1, "mail", "torso")

func _set_wearable(enabled: bool, kind: String, slot: String) -> void:
	var id := IDS[_subject.selected]
	if id not in HUMANS:
		return
	var rig := _models[_subject.selected] as SharedCharacterRig
	if enabled:
		var wearable := load("res://assets/storybook/equipment/%s_%s.tres" % [id, kind]) as CharacterWearable
		var equipped := rig.equip_wearable(wearable)
		if not equipped:
			push_error("Failed to equip fitted storybook wearable: %s/%s" % [id, kind])
	else:
		rig.unequip_wearable(slot)

func _set_weapon(index: int) -> void:
	if IDS[_subject.selected] not in HUMANS:
		return
	var rig := _models[_subject.selected] as SharedCharacterRig
	if index == 0:
		rig.unequip(&"right_hand")
	else:
		var kind := "hammer" if index == 1 else "sword"
		rig.equip(&"right_hand", load("res://assets/storybook/equipment/%s.tscn" % kind))

func _set_shield(enabled: bool) -> void:
	if IDS[_subject.selected] not in HUMANS:
		return
	var rig := _models[_subject.selected] as SharedCharacterRig
	if enabled:
		rig.equip(&"left_hand", load("res://assets/storybook/equipment/shield.tscn"))
	else:
		rig.unequip(&"left_hand")

func _dress_all() -> void:
	for i: int in IDS.size():
		if IDS[i] not in HUMANS:
			continue
		_subject.select(i)
		_set_armor(1)
		_set_wearable(true, "helmet", "head")
		_set_wearable(true, "cape", "back")
		_set_weapon(2)
		_set_shield(true)
		_players[i].play(&"Idle")
		_players[i].advance(0.2)
	_subject.select(0)
	_select_subject(0)

func _start_flight() -> void:
	_stop_flight()
	_flight_time = 0.0
	_flight_stage = -1
	_flight_origins.clear()
	for i: int in IDS.size():
		if IDS[i] in BIRDS:
			_flight_origins[i] = _models[i].position
	_advance_flight(0.0)

func _advance_flight(delta: float) -> void:
	_flight_time += delta
	var stage := mini(int(_flight_time / 2.0), 4)
	if stage != _flight_stage:
		_flight_stage = stage
		var clips: Array[String] = ["TakeOff", "Fly", "Glide", "Land", "Idle"]
		for i: int in IDS.size():
			if IDS[i] in BIRDS:
				_players[i].play(clips[stage], 0.08)
		_select_subject(_subject.selected)
	for key: int in _flight_origins:
		var drift := Vector3.ZERO
		if stage in [1,2]:
			var t := (_flight_time-2.0)/4.0 * TAU
			drift = Vector3(sin(t)*0.5, 0, (1-cos(t))*0.3)
		_models[key].position = _flight_origins[key] + drift
	if stage == 4:
		_flight_time = -1.0
		_flight_origins.clear()

func _stop_flight() -> void:
	for i: int in _flight_origins:
		_models[i].position = _flight_origins[i]
		_players[i].play(&"Idle", 0.08)
	_flight_origins.clear()
	_flight_time = -1.0
	_flight_stage = -1

func _apply_case(index: int) -> void:
	_set_category(1 if index < 4 else 2)
	for i: int in IDS.size():
		if index >= 4:
			if IDS[i] not in HUMANS and IDS[i] not in BIRDS:
				_players[i].play("Graze" if index == 4 else "Alert")
			continue
		if IDS[i] not in HUMANS:
			continue
		_subject.select(i)
		_set_armor(1 if index == 3 else 0)
		_set_wearable(index == 3, "helmet", "head")
		_set_wearable(index in [2, 3], "cape", "back")
		_set_weapon(1 if index == 1 else (2 if index == 3 else 0))
		_set_shield(index == 3)
		var motion: Array[String] = ["Idle", "1H_Melee_Attack_Chop", "Walking_A", "1H_Melee_Attack_Slice_Diagonal"]
		_players[i].play(motion[index])
	_subject.select(0 if index < 4 else HUMANS.size())
	_select_subject(_subject.selected)
