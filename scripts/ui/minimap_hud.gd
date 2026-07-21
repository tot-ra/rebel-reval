class_name MinimapHud
extends CanvasLayer

const TOGGLE_ACTION := &"toggle_minimap"
const MAX_DISPLAY_SIZE := 280.0
const PANEL_MARGIN := 24.0
const INNER_PADDING := 8.0
const LOCATION_GAP := 8.0
const LOCATION_LABEL_HEIGHT := 32.0
const ORNAMENT_INSET := 5.0
const MARKER_SIZE := Vector2(10.0, 10.0)
## Cells spanned by the circular diameter. Large districts pan under the player;
## maps smaller than this still follow, with empty fill outside authored bounds.
const FOLLOW_VIEW_CELLS := 56.0
const CIRCULAR_CLIP_SHADER := preload("res://scripts/ui/circular_clip.gdshader")
const DayNightCycleScript := preload("res://scripts/global/day_night_cycle.gd")
const GameCalendarScript := preload("res://scripts/global/game_calendar.gd")
const CELESTIAL_SIZE := Vector2(52.0, 52.0)
const DATE_BADGE_HEIGHT := 26.0


class MinimapCelestialIndicator:
	extends Control

	var cycle_progress := DayNightCycleScript.DEFAULT_PROGRESS
	var target_progress := DayNightCycleScript.DEFAULT_PROGRESS
	var animation_time := 0.0

	func set_cycle_progress(progress: float) -> void:
		target_progress = wrapf(progress, 0.0, 1.0)
		queue_redraw()

	func _process(delta: float) -> void:
		animation_time += delta
		var current_angle := cycle_progress * TAU
		var target_angle := target_progress * TAU
		cycle_progress = wrapf(lerp_angle(current_angle, target_angle, clampf(delta * 3.5, 0.0, 1.0)) / TAU, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 2.0
		var daylight := DayNightCycleScript.day_blend(cycle_progress)
		var night_sky := Color(0.035, 0.055, 0.11, 0.94)
		var day_sky := Color(0.27, 0.53, 0.67, 0.94)
		draw_circle(center, radius, night_sky.lerp(day_sky, daylight))
		draw_arc(center, radius, 0.0, TAU, 48, Color(0.93, 0.79, 0.48, 0.95), 1.5, true)

		# The miniature orbit mirrors the accelerated world-lighting cycle. The
		# date remains story-authored, while this disc can animate every frame.
		var orbit_angle := cycle_progress * TAU + PI
		var orbit := Vector2(cos(orbit_angle), sin(orbit_angle))
		var body_position := center + orbit * Vector2(radius * 0.58, radius * 0.42)
		if daylight >= 0.5:
			_draw_sun(body_position, daylight)
		else:
			_draw_moon(body_position, 1.0 - daylight)
		var glint_alpha := 0.22 + sin(animation_time * 2.2) * 0.08
		draw_arc(center, radius - 3.0, orbit_angle - 0.35, orbit_angle + 0.35, 12, Color(1.0, 0.88, 0.55, glint_alpha), 1.0, true)

	func _draw_sun(position: Vector2, strength: float) -> void:
		var color := Color(1.0, 0.77, 0.24, clampf(0.65 + strength * 0.35, 0.0, 1.0))
		for ray_index in 8:
			var ray := Vector2.from_angle(float(ray_index) * TAU / 8.0)
			draw_line(position + ray * 7.0, position + ray * 10.0, color, 1.5, true)
		draw_circle(position, 5.5, color)

	func _draw_moon(position: Vector2, strength: float) -> void:
		var moon := Color(0.91, 0.92, 0.78, clampf(0.65 + strength * 0.35, 0.0, 1.0))
		draw_circle(position, 6.0, moon)
		draw_circle(position + Vector2(2.8, -1.4), 5.2, Color(0.07, 0.10, 0.17, moon.a))


class MinimapOrnament:
	extends Control

	const OUTER_GOLD := Color(0.72, 0.58, 0.31, 1.0)
	const INNER_GOLD := Color(0.93, 0.79, 0.48, 0.9)
	const SHADOW_BRONZE := Color(0.23, 0.13, 0.07, 0.95)

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - ORNAMENT_INSET
		draw_arc(center, radius + 2.0, 0.0, TAU, 96, SHADOW_BRONZE, 5.0, true)
		draw_arc(center, radius, 0.0, TAU, 96, OUTER_GOLD, 3.0, true)
		draw_arc(center, radius - 5.0, 0.0, TAU, 96, INNER_GOLD, 1.0, true)

		# Cardinal fleur-like points and small ring studs make the frame read as
		# crafted medieval metalwork without requiring resolution-specific art.
		for index in 4:
			var angle := float(index) * PI * 0.5
			_draw_cardinal_flourish(center, radius, angle)
		for index in 12:
			var angle := float(index) * TAU / 12.0
			var stud := center + Vector2.from_angle(angle) * (radius - 8.0)
			draw_circle(stud, 1.5, INNER_GOLD)

	func _draw_cardinal_flourish(center: Vector2, radius: float, angle: float) -> void:
		var outward := Vector2.from_angle(angle)
		var tangent := outward.orthogonal()
		var tip := center + outward * (radius - 1.0)
		var base := center + outward * (radius - 12.0)
		var diamond := PackedVector2Array([
			tip,
			base + tangent * 5.0,
			base - outward * 5.0,
			base - tangent * 5.0,
		])
		draw_colored_polygon(diamond, SHADOW_BRONZE)
		draw_polyline(PackedVector2Array([tip, base + tangent * 5.0, base - outward * 5.0, base - tangent * 5.0, tip]), INNER_GOLD, 1.5, true)

var _definition: MapDefinition
var _grid: MapTerrainGrid
var _player: Node2D
var _root: Control
var _panel: PanelContainer
var _location_label: Label
var _map_host: Control
var _texture_rect: TextureRect
var _marker: ColorRect
var _map_texture: ImageTexture
var _date_label: Label
var _celestial_indicator: MinimapCelestialIndicator


func configure(definition: MapDefinition, grid: MapTerrainGrid, player: Node2D) -> void:
	_definition = definition
	_grid = grid
	_player = player
	# Headless bootstrap tests add the HUD under an orphan root, so _ready may
	# not have run yet. Build the UI eagerly so location labels are queryable.
	_ensure_ui()
	_apply_location_label(definition)
	_rebuild_map_texture()


func get_location_label() -> Label:
	_ensure_ui()
	return _location_label


func get_date_label() -> Label:
	return _date_label


func get_celestial_indicator() -> Control:
	return _celestial_indicator


## Exposes the same authored map data to the full-screen map mode. Keeping the
## image and marker conversion here prevents the minimap and overlay drifting.
func has_map_data() -> bool:
	return _definition != null and _grid != null


func get_local_map_image() -> Image:
	if not has_map_data():
		return null
	return MinimapTextureBuilder.build_image(_definition, _grid)


func get_player_map_position() -> Vector2:
	if not has_map_data() or _player == null or not is_instance_valid(_player):
		return Vector2(-1.0, -1.0)
	return MinimapTextureBuilder.world_to_normalized(_definition, _player.global_position)


func get_location_name() -> String:
	if _definition == null:
		return ""
	return LocationHud.display_name_for(_definition)


static func map_block_height() -> float:
	return MAX_DISPLAY_SIZE + (INNER_PADDING * 2.0) + PANEL_MARGIN


static func total_hud_height() -> float:
	return LOCATION_LABEL_HEIGHT + LOCATION_GAP + map_block_height()


func is_enabled() -> bool:
	return visible


func toggle() -> void:
	visible = not visible


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_ui()
	_rebuild_map_texture()
	_connect_time_sources()
	_update_calendar_date(MusicDirector.current_calendar_date())
	_update_cycle_progress(MusicDirector.get_cycle_progress())
	set_process(true)


func _ensure_ui() -> void:
	if _root != null:
		return
	_build_ui()


func _exit_tree() -> void:
	if MusicDirector.cycle_progress_changed.is_connected(_update_cycle_progress):
		MusicDirector.cycle_progress_changed.disconnect(_update_cycle_progress)
	if MusicDirector.calendar_date_changed.is_connected(_update_calendar_date):
		MusicDirector.calendar_date_changed.disconnect(_update_calendar_date)


func _process(_delta: float) -> void:
	_update_marker()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_toggle_event(event):
		return
	get_viewport().set_input_as_handled()
	toggle()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "MinimapRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_root.offset_left = -MAX_DISPLAY_SIZE - (INNER_PADDING * 2.0) - PANEL_MARGIN
	_root.offset_top = PANEL_MARGIN
	_root.offset_right = -PANEL_MARGIN
	_root.offset_bottom = total_hud_height()
	add_child(_root)

	var stack := VBoxContainer.new()
	stack.name = "MinimapStack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", LOCATION_GAP)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(stack)

	_location_label = Label.new()
	_location_label.name = "LocationLabel"
	_location_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_location_label.custom_minimum_size.y = LOCATION_LABEL_HEIGHT
	_location_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.81, 1.0))
	_location_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.06, 0.05, 0.9))
	_location_label.add_theme_constant_override("shadow_offset_x", 2)
	_location_label.add_theme_constant_override("shadow_offset_y", 2)
	_location_label.add_theme_font_size_override("font_size", 24)
	stack.add_child(_location_label)

	_panel = PanelContainer.new()
	_panel.name = "MinimapPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_panel_style()
	stack.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", INNER_PADDING)
	margin.add_theme_constant_override("margin_right", INNER_PADDING)
	margin.add_theme_constant_override("margin_top", INNER_PADDING)
	margin.add_theme_constant_override("margin_bottom", INNER_PADDING)
	_panel.add_child(margin)

	_map_host = Control.new()
	_map_host.name = "MapHost"
	_map_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_map_host)

	_texture_rect = TextureRect.new()
	_texture_rect.name = "MapTexture"
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clip_material := ShaderMaterial.new()
	clip_material.shader = CIRCULAR_CLIP_SHADER
	_texture_rect.material = clip_material
	_map_host.add_child(_texture_rect)

	_marker = ColorRect.new()
	_marker.name = "PlayerMarker"
	_marker.color = Color(0.95, 0.28, 0.22, 1.0)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.size = MARKER_SIZE
	_map_host.add_child(_marker)

	_celestial_indicator = MinimapCelestialIndicator.new()
	_celestial_indicator.name = "DayNightIndicator"
	_celestial_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_celestial_indicator.custom_minimum_size = CELESTIAL_SIZE
	_celestial_indicator.size = CELESTIAL_SIZE
	_celestial_indicator.position = Vector2(MAX_DISPLAY_SIZE - CELESTIAL_SIZE.x - 10.0, 10.0)
	_map_host.add_child(_celestial_indicator)

	var date_badge := PanelContainer.new()
	date_badge.name = "CalendarDateBadge"
	date_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	date_badge.custom_minimum_size = Vector2(112.0, DATE_BADGE_HEIGHT)
	date_badge.size = date_badge.custom_minimum_size
	date_badge.position = Vector2((MAX_DISPLAY_SIZE - date_badge.size.x) * 0.5, MAX_DISPLAY_SIZE - DATE_BADGE_HEIGHT - 14.0)
	date_badge.add_theme_stylebox_override("panel", _date_badge_style())
	_map_host.add_child(date_badge)

	_date_label = Label.new()
	_date_label.name = "CalendarDate"
	_date_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_date_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.81, 1.0))
	_date_label.add_theme_color_override("font_shadow_color", Color(0.05, 0.035, 0.025, 0.95))
	_date_label.add_theme_constant_override("shadow_offset_x", 1)
	_date_label.add_theme_constant_override("shadow_offset_y", 2)
	_date_label.add_theme_font_size_override("font_size", 16)
	date_badge.add_child(_date_label)

	var ornament := MinimapOrnament.new()
	ornament.name = "MedievalOrnament"
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_host.add_child(ornament)
	_map_host.move_child(ornament, 1)


func _connect_time_sources() -> void:
	if not MusicDirector.cycle_progress_changed.is_connected(_update_cycle_progress):
		MusicDirector.cycle_progress_changed.connect(_update_cycle_progress)
	if not MusicDirector.calendar_date_changed.is_connected(_update_calendar_date):
		MusicDirector.calendar_date_changed.connect(_update_calendar_date)


func _update_cycle_progress(progress: float) -> void:
	if _celestial_indicator != null:
		_celestial_indicator.set_cycle_progress(progress)


func _update_calendar_date(date: Dictionary) -> void:
	if _date_label != null:
		_date_label.text = GameCalendarScript.format_date(date)


func _date_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.055, 0.025, 0.84)
	style.border_color = Color(0.72, 0.58, 0.31, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	return style


func _rebuild_map_texture() -> void:
	if _texture_rect == null or _definition == null or _grid == null:
		return

	var image := MinimapTextureBuilder.build_image(_definition, _grid)
	_map_texture = ImageTexture.create_from_image(image)
	_texture_rect.texture = _map_texture
	_apply_follow_shader_statics()

	_apply_map_layout()
	_apply_location_label(_definition)
	_update_marker()


func _apply_location_label(definition: MapDefinition) -> void:
	if _location_label == null:
		return
	var location_name := LocationHud.display_name_for(definition)
	_location_label.text = location_name
	_location_label.visible = not location_name.is_empty()


func _display_size_for_map() -> Vector2:
	return Vector2(MAX_DISPLAY_SIZE, MAX_DISPLAY_SIZE)


func get_follow_center_uv() -> Vector2:
	if _texture_rect == null:
		return Vector2(-1.0, -1.0)
	var material := _texture_rect.material as ShaderMaterial
	if material == null:
		return Vector2(-1.0, -1.0)
	return material.get_shader_parameter("center_uv") as Vector2


func get_follow_view_cells() -> float:
	return FOLLOW_VIEW_CELLS


func _apply_follow_shader_statics() -> void:
	if _texture_rect == null or _definition == null:
		return
	var material := _texture_rect.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("view_cells", FOLLOW_VIEW_CELLS)
	material.set_shader_parameter(
		"map_cells",
		Vector2(float(_definition.size_cells.x), float(_definition.size_cells.y))
	)


func _update_marker() -> void:
	if _marker == null or _player == null or _definition == null or not is_instance_valid(_player):
		if _marker != null:
			_marker.visible = false
		return

	var normalized := MinimapTextureBuilder.world_to_normalized(_definition, _player.global_position)
	var material := _texture_rect.material as ShaderMaterial
	if material != null:
		# Pan the authored map under a fixed center marker so local travel reads
		# clearly; the M overlay still shows the full district.
		material.set_shader_parameter("center_uv", normalized)

	var circle_center := Vector2(MAX_DISPLAY_SIZE, MAX_DISPLAY_SIZE) * 0.5
	_marker.visible = visible
	_marker.position = circle_center - MARKER_SIZE * 0.5


func _is_toggle_event(event: InputEvent) -> bool:
	return event.is_action_pressed(TOGGLE_ACTION) and not event.is_echo()


func _apply_panel_style() -> void:
	var radius := int(MAX_DISPLAY_SIZE * 0.5) + INNER_PADDING
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.035, 0.025, 0.96)
	style.border_color = Color(0.24, 0.13, 0.06, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 8
	_panel.add_theme_stylebox_override("panel", style)


func _apply_map_layout() -> void:
	var host_size := Vector2(MAX_DISPLAY_SIZE, MAX_DISPLAY_SIZE)
	_map_host.custom_minimum_size = host_size
	_map_host.size = host_size
	_texture_rect.custom_minimum_size = host_size
	_texture_rect.position = Vector2.ZERO
	_texture_rect.size = host_size
