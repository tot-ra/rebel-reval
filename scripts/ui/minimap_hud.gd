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
const CIRCULAR_CLIP_SHADER := preload("res://scripts/ui/circular_clip.gdshader")


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


func configure(definition: MapDefinition, grid: MapTerrainGrid, player: Node2D) -> void:
	_definition = definition
	_grid = grid
	_player = player
	if is_node_ready():
		_apply_location_label(definition)
		_rebuild_map_texture()


func get_location_label() -> Label:
	return _location_label


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
	_build_ui()
	_rebuild_map_texture()
	set_process(true)


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

	var ornament := MinimapOrnament.new()
	ornament.name = "MedievalOrnament"
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_host.add_child(ornament)


func _rebuild_map_texture() -> void:
	if _texture_rect == null or _definition == null or _grid == null:
		return

	var image := MinimapTextureBuilder.build_image(_definition, _grid)
	_map_texture = ImageTexture.create_from_image(image)
	_texture_rect.texture = _map_texture
	(_texture_rect.material as ShaderMaterial).set_shader_parameter(
		"map_aspect",
		float(image.get_width()) / float(image.get_height())
	)

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


func _map_uv_for_normalized(normalized: Vector2) -> Vector2:
	if _definition == null or _definition.size_cells.x <= 0 or _definition.size_cells.y <= 0:
		return Vector2.ZERO
	var aspect := float(_definition.size_cells.x) / float(_definition.size_cells.y)
	if aspect > 1.0:
		return Vector2((normalized.x - 0.5) * aspect + 0.5, normalized.y)
	return Vector2(normalized.x, (normalized.y - 0.5) / aspect + 0.5)


func _update_marker() -> void:
	if _marker == null or _player == null or _definition == null or not is_instance_valid(_player):
		_marker.visible = false
		return

	var normalized := MinimapTextureBuilder.world_to_normalized(_definition, _player.global_position)
	var marker_center := _map_uv_for_normalized(normalized) * _texture_rect.size
	var circle_center := Vector2(MAX_DISPLAY_SIZE, MAX_DISPLAY_SIZE) * 0.5
	var marker_radius := MARKER_SIZE.length() * 0.5
	var marker_inside_circle := marker_center.distance_to(circle_center) <= (MAX_DISPLAY_SIZE * 0.5) - marker_radius
	_marker.visible = visible and marker_inside_circle
	_marker.position = marker_center - MARKER_SIZE * 0.5


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
