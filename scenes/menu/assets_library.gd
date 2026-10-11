extends Control

## Main-menu 3D asset library: list every imported model, orbit it, play clips.

const Catalog := preload("res://scripts/ui/asset_library_catalog.gd")
const MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const GOLD := Color(0.980392, 0.839216, 0.0235294)
const PANEL := Color(0.0392157, 0.0313726, 0.0470588, 0.96)
const DEFAULT_YAW := 0.72
const DEFAULT_PITCH := 0.38
const MIN_DISTANCE := 0.6
const MAX_DISTANCE := 80.0
const ORBIT_SPEED := 0.55

var _entries: Array[Dictionary] = []
var _filtered: Array[Dictionary] = []
var _current_path := ""
var _model: Node3D
var _player: AnimationPlayer
var _world: Node3D
var _pivot: Node3D
var _camera: Camera3D
var _yaw := DEFAULT_YAW
var _pitch := DEFAULT_PITCH
var _distance := 4.0
var _look_at := Vector3(0.0, 1.0, 0.0)
var _auto_rotate := false
var _list: ItemList
var _search: LineEdit
var _category: OptionButton
var _clips: OptionButton
var _info: Label
var _back: RichTextLabel
var _auto_btn: CheckButton
var _select_btn: Button
var _select_status: Label
# Sticky multi-select, separate from the single-item preview highlight, so
# Enter / Select can accumulate paths and publish them to the clipboard.
var _selected_paths: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_entries = Catalog.list_models()
	_build_ui()
	_rebuild_list()
	if _filtered.is_empty():
		_info.text = "No imported GLB/GLTF models found under res://assets."
		_select_btn.disabled = true
		_back.grab_focus()
		return
	_list.select(0)
	_show_index(0)
	_list.grab_focus()


func current_path() -> String:
	return _current_path


func current_clips() -> PackedStringArray:
	if _model == null:
		return PackedStringArray()
	return Catalog.clip_names_for(_model)


func filtered_count() -> int:
	return _filtered.size()


func selected_model_paths() -> PackedStringArray:
	return _selected_paths.duplicate()


func selected_models_clipboard_text() -> String:
	return "\n".join(_selected_paths)


func select_current_model() -> bool:
	if _current_path.is_empty():
		return false
	if not _selected_paths.has(_current_path):
		_selected_paths.append(_current_path)
	_refresh_selection_marks()
	_update_select_status()
	_copy_selected_to_clipboard()
	return true


func _copy_selected_to_clipboard() -> void:
	# Headless CI has no pasteboard; keep the in-memory list either way.
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		return
	DisplayServer.clipboard_set(selected_models_clipboard_text())


func show_model(path: String) -> bool:
	var packed := load(path) as PackedScene
	if packed == null:
		_info.text = "Could not load %s" % path
		return false
	var instance := packed.instantiate() as Node3D
	if instance == null:
		_info.text = "Not a 3D scene: %s" % path
		return false
	_clear_model()
	_model = instance
	_model.name = "PreviewModel"
	_pivot.add_child(_model)
	_current_path = path
	_player = Catalog.animation_player_for(_model)
	if _player != null and not _player.animation_finished.is_connected(
		_on_clip_finished
	):
		_player.animation_finished.connect(_on_clip_finished)
	_fill_clips()
	_reset_orbit()
	_update_camera()
	_update_info()
	return true


func apply_orbit(yaw_delta: float, pitch_delta: float) -> void:
	_yaw += yaw_delta
	_pitch = clampf(_pitch + pitch_delta, 0.08, 1.35)
	_update_camera()


func play_clip(clip_name: String) -> bool:
	if _player == null or clip_name.is_empty():
		return false
	if not _player.has_animation(clip_name):
		return false
	_player.play(clip_name)
	return true


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = PANEL
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 20)
	root.offset_left = 28.0
	root.offset_top = 24.0
	root.offset_right = -28.0
	root.offset_bottom = -24.0
	add_child(root)

	root.add_child(_build_sidebar())
	root.add_child(_build_stage())


func _build_sidebar() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(360, 0)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "Assets library"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", GOLD)
	side.add_child(title)

	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = (
		"Every imported 3D model under assets/. "
		+ "Select model or Enter adds the current preview to a list "
		+ "and copies every selected path to the clipboard."
	)
	hint.add_theme_font_size_override("font_size", 14)
	side.add_child(hint)

	_search = LineEdit.new()
	_search.name = "SearchField"
	_search.placeholder_text = "Filter by name or folder"
	_search.text_changed.connect(_on_filter_changed)
	side.add_child(_search)

	_category = OptionButton.new()
	_category.name = "CategoryFilter"
	_category.add_item("All categories")
	for category: String in Catalog.categories_for(_entries):
		_category.add_item(category)
	_category.item_selected.connect(_on_category_selected)
	side.add_child(_category)

	_list = ItemList.new()
	_list.name = "ModelList"
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_show_index)
	side.add_child(_list)

	_select_btn = Button.new()
	_select_btn.name = "SelectModelButton"
	_select_btn.text = "Select model"
	_select_btn.pressed.connect(_on_select_model)
	side.add_child(_select_btn)

	_select_status = Label.new()
	_select_status.name = "SelectStatusLabel"
	_select_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_select_status.add_theme_font_size_override("font_size", 14)
	_update_select_status()
	side.add_child(_select_status)

	_back = RichTextLabel.new()
	_back.name = "BackLabel"
	_back.custom_minimum_size = Vector2(0, 48)
	_back.focus_mode = Control.FOCUS_ALL
	_back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_back.add_theme_color_override("default_color", GOLD)
	_back.add_theme_font_size_override("normal_font_size", 28)
	_back.text = "Back"
	_back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_back.gui_input.connect(_on_back_input)
	side.add_child(_back)
	return side


func _build_stage() -> Control:
	var stage := VBoxContainer.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_constant_override("separation", 10)

	var host := SubViewportContainer.new()
	host.name = "PreviewHost"
	host.stretch = true
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.gui_input.connect(_on_preview_input)
	stage.add_child(host)

	var viewport := SubViewport.new()
	viewport.name = "PreviewViewport"
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	host.add_child(viewport)
	_populate_world(viewport)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	stage.add_child(controls)

	_clips = OptionButton.new()
	_clips.name = "ClipList"
	_clips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clips.item_selected.connect(_on_clip_selected)
	controls.add_child(_clips)

	_auto_btn = CheckButton.new()
	_auto_btn.text = "Auto-rotate"
	_auto_btn.toggled.connect(_on_auto_rotate)
	controls.add_child(_auto_btn)

	var reset := Button.new()
	reset.text = "Reset view"
	reset.pressed.connect(_on_reset_view)
	controls.add_child(reset)

	_info = Label.new()
	_info.name = "InfoLabel"
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 15)
	stage.add_child(_info)
	return stage


func _populate_world(viewport: SubViewport) -> void:
	_world = Node3D.new()
	_world.name = "PreviewWorld"
	viewport.add_child(_world)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2b3138")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d2dfeb")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	_world.add_child(environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	key.light_color = Color("ffe0b4")
	key.light_energy = 0.85
	_world.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35.0, 130.0, 0.0)
	fill.light_color = Color("b6d3f1")
	fill.light_energy = 0.28
	_world.add_child(fill)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3a414a")
	mat.roughness = 1.0
	ground.material_override = mat
	ground.position.y = -0.02
	_world.add_child(ground)

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_world.add_child(_pivot)

	_camera = Camera3D.new()
	_camera.name = "PreviewCamera"
	_camera.fov = 38.0
	_world.add_child(_camera)


func _rebuild_list() -> void:
	var category := ""
	if _category.selected > 0:
		category = _category.get_item_text(_category.selected)
	_filtered = Catalog.filter_entries(_entries, _search.text, category)
	_list.clear()
	for entry in _filtered:
		var index := _list.add_item(_item_label(entry))
		_list.set_item_metadata(index, entry["path"])


func _item_label(entry: Dictionary) -> String:
	var label := "%s  ·  %s" % [entry["display_name"], entry["folder"]]
	if _selected_paths.has(String(entry["path"])):
		return "●  %s" % label
	return label


func _refresh_selection_marks() -> void:
	for i: int in _list.item_count:
		if i >= _filtered.size():
			break
		_list.set_item_text(i, _item_label(_filtered[i]))


func _update_select_status() -> void:
	if _select_status == null:
		return
	if _selected_paths.is_empty():
		_select_status.text = "No models selected"
		return
	var noun := "model" if _selected_paths.size() == 1 else "models"
	_select_status.text = "%d %s selected · copied to clipboard" % [
		_selected_paths.size(),
		noun,
	]


func _on_select_model() -> void:
	select_current_model()


func _show_index(index: int) -> void:
	if index < 0 or index >= _filtered.size():
		return
	show_model(String(_filtered[index]["path"]))


func _fill_clips() -> void:
	_clips.clear()
	var clips := current_clips()
	if clips.is_empty():
		_clips.add_item("No animations")
		_clips.disabled = true
		return
	_clips.disabled = false
	var preferred := Catalog.preferred_clip(clips)
	var selected := 0
	for i: int in clips.size():
		_clips.add_item(clips[i])
		if clips[i] == preferred:
			selected = i
	_clips.select(selected)
	play_clip(clips[selected])


func _reset_orbit() -> void:
	_yaw = DEFAULT_YAW
	_pitch = DEFAULT_PITCH
	if _model == null:
		_look_at = Vector3(0.0, 1.0, 0.0)
		_distance = 4.0
		return
	var bounds := Catalog.combined_aabb(_model)
	if bounds.size == Vector3.ZERO:
		_look_at = Vector3(0.0, 1.0, 0.0)
		_distance = 4.0
		return
	_look_at = bounds.get_center()
	_distance = clampf(bounds.size.length() * 1.15, MIN_DISTANCE, MAX_DISTANCE)


func _on_reset_view() -> void:
	_reset_orbit()
	_update_camera()


func _update_camera() -> void:
	if _camera == null:
		return
	var offset := Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		cos(_yaw) * cos(_pitch)
	) * _distance
	var from := _look_at + offset
	if _camera.is_inside_tree():
		_camera.look_at_from_position(from, _look_at)
	else:
		_camera.position = from


func _update_info() -> void:
	if _model == null:
		return
	var clips := current_clips()
	var clip_text := "none"
	if not clips.is_empty():
		clip_text = "%d: %s" % [clips.size(), ", ".join(clips)]
	var bounds := Catalog.combined_aabb(_model)
	var hint := (
		"Drag preview to orbit · wheel zoom · Q/E rotate · Esc back"
		+ " · Enter selects the current model"
	)
	_info.text = "%s\n%s meshes · size %.2f x %.2f x %.2f m\nClips: %s\n%s" % [
		_current_path,
		Catalog.mesh_count(_model),
		bounds.size.x,
		bounds.size.y,
		bounds.size.z,
		clip_text,
		hint,
	]


func _clear_model() -> void:
	if _player != null and _player.animation_finished.is_connected(
		_on_clip_finished
	):
		_player.animation_finished.disconnect(_on_clip_finished)
	_player = null
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = null
	_current_path = ""


func _on_filter_changed(_text: String) -> void:
	_rebuild_list()
	if _filtered.is_empty():
		_info.text = "No models match this filter."
		_select_btn.disabled = true
		return
	_select_btn.disabled = false
	_list.select(0)
	_show_index(0)


func _on_category_selected(_index: int) -> void:
	_on_filter_changed(_search.text)


func _on_clip_selected(index: int) -> void:
	if _clips.disabled:
		return
	play_clip(_clips.get_item_text(index))


func _on_auto_rotate(enabled: bool) -> void:
	_auto_rotate = enabled


func _on_clip_finished(clip_name: StringName) -> void:
	if _player == null:
		return
	if String(_player.current_animation).is_empty():
		_player.play(String(clip_name))


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			apply_orbit(-motion.relative.x * 0.008, motion.relative.y * 0.005)
	elif event is InputEventMouseButton and event.pressed:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(MIN_DISTANCE, _distance * 0.9)
			_update_camera()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(MAX_DISTANCE, _distance * 1.1)
			_update_camera()


func _on_back_input(event: InputEvent) -> void:
	if _is_activate(event):
		_go_back()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	if key.keycode != KEY_ENTER and key.keycode != KEY_KP_ENTER:
		return
	if not _can_select_from_enter():
		return
	select_current_model()
	get_viewport().set_input_as_handled()


func _can_select_from_enter() -> bool:
	if _current_path.is_empty():
		return false
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		return true
	if focused == _search or focused == _back:
		return false
	if focused == _category or focused == _clips:
		return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_go_back()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_Q:
			apply_orbit(0.12, 0.0)
		elif key.keycode == KEY_E:
			apply_orbit(-0.12, 0.0)


func _process(delta: float) -> void:
	if _auto_rotate:
		apply_orbit(delta * ORBIT_SPEED, 0.0)


func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _is_activate(event: InputEvent) -> bool:
	return (
		event.is_action_pressed(&"ui_accept")
		or (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
			and (event as InputEventMouseButton).pressed
		)
	)
