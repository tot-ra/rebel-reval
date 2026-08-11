class_name DebugOverlay
extends CanvasLayer

## Debug overlay showing FPS, active audio, and time speed controls.
## Toggle from the QuickAccessMenu "Debug" button. Time speed keys
## (comma/period/P) were removed; all controls are visual-only.

const PANEL_MARGIN := 12.0
const PANEL_WIDTH := 320.0
const PANEL_HEIGHT := 380.0
const ASSET_SHOWCASE_SCENE := "res://scenes/debug/asset_showcase.tscn"
const LARGE_ASSET_SHOWCASE_SCENE := "res://scenes/debug/asset_showcase_large.tscn"
const CHARACTERS_ANIMALS_SHOWCASE_SCENE := "res://scenes/debug/characters_animals_showcase.tscn"
const ASSET_SHOWCASE_SCENES: Array[String] = [
	ASSET_SHOWCASE_SCENE,
	LARGE_ASSET_SHOWCASE_SCENE,
	CHARACTERS_ANIMALS_SHOWCASE_SCENE,
]
const BG_COLOR := Color(0.0, 0.0, 0.0, 0.75)
const TEXT_COLOR := Color(0.9, 0.9, 0.9, 1.0)
const LABEL_COLOR := Color(0.6, 0.8, 1.0, 1.0)
const ACCENT_COLOR := Color(1.0, 0.85, 0.4, 1.0)
const FONT_SIZE := 13
const HEADER_SIZE := 15

var _panel: PanelContainer
var _fps_label: Label
var _music_label: Label
var _bird_label: Label
var _insect_label: Label
var _rain_label: Label
var _time_speed_label: Label
var _pause_button: Button
var _speed_down_button: Button
var _speed_up_button: Button
var _reset_button: Button
var _small_asset_showcase_button: Button
var _large_asset_showcase_button: Button
var _characters_animals_showcase_button: Button
var _runtime: MapViewRuntime


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func toggle_visibility() -> void:
	visible = not visible
	if visible:
		_resolve_runtime()


func set_runtime(runtime: MapViewRuntime) -> void:
	_runtime = runtime
	if is_node_ready():
		_refresh_time_controls()


func _resolve_runtime() -> void:
	if _runtime != null and is_instance_valid(_runtime):
		return
	# Walk up to find the MapViewRuntime sibling (same parent as QuickAccessMenu).
	var node := get_parent()
	while node != null:
		if node.has_node("MapViewRuntime"):
			_runtime = node.get_node("MapViewRuntime") as MapViewRuntime
			return
		node = node.get_parent()


func _process(_delta: float) -> void:
	if not visible:
		return
	_update_fps()
	_update_audio_info()
	_update_time_controls()


func _update_fps() -> void:
	if _fps_label == null:
		return
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _update_audio_info() -> void:
	# Music theme from the global MusicDirector autoload.
	var music_director := _find_music_director()
	if music_director != null and _music_label != null:
		var theme_id: StringName = music_director.active_theme_id()
		var status := "playing" if music_director.is_theme_playing() else "silenced"
		if theme_id.is_empty():
			_music_label.text = "Music: none"
		else:
			_music_label.text = "Music: %s (%s)" % [String(theme_id), status]
	elif _music_label != null:
		_music_label.text = "Music: unavailable"

	# Bird voices from MapViewRuntime children.
	if _runtime != null and is_instance_valid(_runtime):
		var bird_count: int = _runtime.bird_audio_active_voice_count()
		_bird_label.text = "Bird voices: %d / 3" % bird_count

		var insect_count: int = _runtime.insect_audio_active_voice_count()
		_insect_label.text = "Insect voices: %d / 3" % insect_count

		# Roof rain audio via the sky weather child on MapView3D.
		var view: MapView3D = _runtime.view
		var sky = view.sky_weather() if view != null else null
		if sky != null:
			if sky.roof_audio_active():
				_rain_label.text = (
					"Roof rain: on (%.0f%%)" % (sky.roof_audio_linear_volume() * 100.0)
				)
			else:
				_rain_label.text = "Roof rain: off"
		else:
			_rain_label.text = "Roof rain: n/a"
	else:
		_bird_label.text = "Bird voices: -"
		_insect_label.text = "Insect voices: -"
		_rain_label.text = "Roof rain: -"


func _update_time_controls() -> void:
	if _runtime == null or not is_instance_valid(_runtime):
		_time_speed_label.text = "Time: -"
		return
	var speed := _runtime.effective_time_speed()
	var paused := _runtime.time_paused
	if paused:
		_time_speed_label.text = "Time: PAUSED"
		_time_speed_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
	else:
		_time_speed_label.text = "Time: %.2fx" % speed
		_time_speed_label.add_theme_color_override("font_color", ACCENT_COLOR)
	_pause_button.text = "Resume" if paused else "Pause"


func _refresh_time_controls() -> void:
	if _time_speed_label == null or _pause_button == null:
		return
	if _runtime == null or not is_instance_valid(_runtime):
		return
	_time_speed_label.text = "Time: %.2fx" % _runtime.effective_time_speed()
	_pause_button.text = "Resume" if _runtime.time_paused else "Pause"


func _find_music_director() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("MusicDirector")


# -- UI construction --


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DebugPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = PANEL_MARGIN
	_panel.offset_top = PANEL_MARGIN
	_panel.offset_right = PANEL_MARGIN + PANEL_WIDTH
	_panel.offset_bottom = PANEL_MARGIN + PANEL_HEIGHT

	# Semi-transparent background.
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 4)
	_panel.add_child(layout)

	# Header
	var header := Label.new()
	header.text = "DEBUG OVERLAY"
	header.add_theme_font_size_override("font_size", HEADER_SIZE)
	header.add_theme_color_override("font_color", ACCENT_COLOR)
	layout.add_child(header)

	_add_separator(layout)

	# FPS
	_fps_label = _add_label(layout, "FPS: 0")

	_add_separator(layout)

	# Audio section header
	var audio_header := Label.new()
	audio_header.text = "-- Audio --"
	audio_header.add_theme_font_size_override("font_size", FONT_SIZE)
	audio_header.add_theme_color_override("font_color", LABEL_COLOR)
	layout.add_child(audio_header)

	_music_label = _add_label(layout, "Music: none")
	_bird_label = _add_label(layout, "Bird voices: 0 / 3")
	_insect_label = _add_label(layout, "Insect voices: 0 / 3")
	_rain_label = _add_label(layout, "Roof rain: off")

	_add_separator(layout)

	# Time controls section header
	var time_header := Label.new()
	time_header.text = "-- Time Controls --"
	time_header.add_theme_font_size_override("font_size", FONT_SIZE)
	time_header.add_theme_color_override("font_color", LABEL_COLOR)
	layout.add_child(time_header)

	_time_speed_label = _add_label(layout, "Time: 1.00x")

	# Time control buttons row
	var button_row := HBoxContainer.new()
	button_row.name = "TimeButtons"
	button_row.mouse_filter = Control.MOUSE_FILTER_STOP
	button_row.add_theme_constant_override("separation", 6)
	layout.add_child(button_row)

	_pause_button = _create_button("PauseButton", "Pause", _on_pause_pressed)
	button_row.add_child(_pause_button)

	_speed_down_button = _create_button("SlowerButton", "Slower", _on_speed_down_pressed)
	button_row.add_child(_speed_down_button)

	_speed_up_button = _create_button("FasterButton", "Faster", _on_speed_up_pressed)
	button_row.add_child(_speed_up_button)

	_reset_button = _create_button("ResetButton", "Reset", _on_reset_pressed)
	button_row.add_child(_reset_button)

	_add_separator(layout)

	var scene_header := Label.new()
	scene_header.text = "-- Review Scenes --"
	scene_header.add_theme_font_size_override("font_size", FONT_SIZE)
	scene_header.add_theme_color_override("font_color", LABEL_COLOR)
	layout.add_child(scene_header)

	_small_asset_showcase_button = _create_button(
		"SmallAssetShowcaseButton",
		(
			"Return to previous scene"
			if _is_current_asset_showcase(ASSET_SHOWCASE_SCENE)
			else "Open small assets"
		),
		func() -> void: _open_asset_showcase(ASSET_SHOWCASE_SCENE)
	)
	_small_asset_showcase_button.tooltip_text = (
		"Review furniture, tools, and other relatively "
		+ "small non-living props"
	)
	layout.add_child(_small_asset_showcase_button)

	_characters_animals_showcase_button = _create_button(
		"CharactersAnimalsShowcaseButton",
		(
			"Return to previous scene"
			if _is_current_asset_showcase(CHARACTERS_ANIMALS_SHOWCASE_SCENE)
			else "Open characters / animals"
		),
		func() -> void: _open_asset_showcase(CHARACTERS_ANIMALS_SHOWCASE_SCENE)
	)
	# gdlint: ignore=max-line-length
	_characters_animals_showcase_button.tooltip_text = "Review every humanoid, animated character clip, bird, cat, rat, and other living fauna"
	layout.add_child(_characters_animals_showcase_button)

	_large_asset_showcase_button = _create_button(
		"LargeAssetShowcaseButton",
		(
			"Return to previous scene"
			if _is_current_asset_showcase(LARGE_ASSET_SHOWCASE_SCENE)
			else "Open large assets"
		),
		func() -> void: _open_asset_showcase(LARGE_ASSET_SHOWCASE_SCENE)
	)
	# gdlint: ignore=max-line-length
	_large_asset_showcase_button.tooltip_text = "Review terrain materials, buildings, trees, ships, and facade assets on a spacious grid"
	layout.add_child(_large_asset_showcase_button)


func _add_label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sep)


func _create_button(node_name: String, label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label_text
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	return button


# -- Time control callbacks --


func _on_pause_pressed() -> void:
	_resolve_runtime()
	if _runtime != null and is_instance_valid(_runtime):
		_runtime.toggle_time_pause()
		_refresh_time_controls()


func _on_speed_down_pressed() -> void:
	_resolve_runtime()
	if _runtime != null and is_instance_valid(_runtime):
		_runtime.time_speed_down()
		_refresh_time_controls()


func _on_speed_up_pressed() -> void:
	_resolve_runtime()
	if _runtime != null and is_instance_valid(_runtime):
		_runtime.time_speed_up()
		_refresh_time_controls()


func _on_reset_pressed() -> void:
	_resolve_runtime()
	if _runtime != null and is_instance_valid(_runtime):
		_runtime.reset_time_flow()
		_refresh_time_controls()


func is_asset_showcase_scene() -> bool:
	var current := get_tree().current_scene if is_inside_tree() else null
	return current != null and current.scene_file_path in ASSET_SHOWCASE_SCENES


func _is_current_asset_showcase(scene_path: String) -> bool:
	var current := get_tree().current_scene if is_inside_tree() else null
	return current != null and current.scene_file_path == scene_path


func _open_asset_showcase(scene_path: String) -> void:
	var tree := get_tree()
	var current := tree.current_scene
	if current != null and current.scene_file_path == scene_path:
		_return_from_asset_showcase(tree)
		return

	# Switching between the two catalogs must preserve the original return path,
	# otherwise Return would only bounce back to the other debug gallery.
	if (
		current != null
		and current.scene_file_path not in ASSET_SHOWCASE_SCENES
		and not current.scene_file_path.is_empty()
	):
		tree.root.set_meta(&"debug_asset_showcase_return_path", current.scene_file_path)
	tree.change_scene_to_file(scene_path)


func _return_from_asset_showcase(tree: SceneTree) -> void:
	var return_path := String(tree.root.get_meta(&"debug_asset_showcase_return_path", ""))
	if return_path.is_empty() or not ResourceLoader.exists(return_path, "PackedScene"):
		return_path = String(ProjectSettings.get_setting("application/run/main_scene", ""))
	if not return_path.is_empty():
		tree.change_scene_to_file(return_path)
