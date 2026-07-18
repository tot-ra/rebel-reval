class_name MinimapHud
extends CanvasLayer

const TOGGLE_ACTION := &"toggle_minimap"
const MAX_DISPLAY_SIZE := 200.0
const MARKER_SIZE := Vector2(8.0, 8.0)

var _definition: MapDefinition
var _grid: MapTerrainGrid
var _player: Node2D
var _panel: PanelContainer
var _map_host: Control
var _texture_rect: TextureRect
var _marker: ColorRect
var _map_texture: ImageTexture


func configure(definition: MapDefinition, grid: MapTerrainGrid, player: Node2D) -> void:
	_definition = definition
	_grid = grid
	_player = player
	if is_node_ready():
		_rebuild_map_texture()


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
	_panel = PanelContainer.new()
	_panel.name = "MinimapPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.offset_left = -MAX_DISPLAY_SIZE - 24.0
	_panel.offset_top = -MAX_DISPLAY_SIZE - 24.0
	_panel.offset_right = -24.0
	_panel.offset_bottom = -24.0
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	_map_host = Control.new()
	_map_host.name = "MapHost"
	_map_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_map_host)

	_texture_rect = TextureRect.new()
	_texture_rect.name = "MapTexture"
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_host.add_child(_texture_rect)

	_marker = ColorRect.new()
	_marker.name = "PlayerMarker"
	_marker.color = Color(0.95, 0.28, 0.22, 1.0)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.size = MARKER_SIZE
	_map_host.add_child(_marker)


func _rebuild_map_texture() -> void:
	if _texture_rect == null or _definition == null or _grid == null:
		return

	var image := MinimapTextureBuilder.build_image(_definition, _grid)
	_map_texture = ImageTexture.create_from_image(image)
	_texture_rect.texture = _map_texture

	var display_size := _display_size_for_map()
	_map_host.custom_minimum_size = display_size
	_map_host.size = display_size
	_texture_rect.custom_minimum_size = display_size
	_texture_rect.size = display_size
	_update_marker()


func _display_size_for_map() -> Vector2:
	if _definition == null:
		return Vector2.ZERO
	var world_size := _definition.size_cells
	if world_size.x <= 0 or world_size.y <= 0:
		return Vector2.ZERO
	var scale := minf(
		MAX_DISPLAY_SIZE / float(world_size.x),
		MAX_DISPLAY_SIZE / float(world_size.y)
	)
	return Vector2(float(world_size.x) * scale, float(world_size.y) * scale)


func _update_marker() -> void:
	if _marker == null or _player == null or _definition == null or not is_instance_valid(_player):
		_marker.visible = false
		return

	_marker.visible = visible
	var normalized := MinimapTextureBuilder.world_to_normalized(_definition, _player.global_position)
	var map_size := _texture_rect.size
	_marker.position = normalized * map_size - MARKER_SIZE * 0.5


func _is_toggle_event(event: InputEvent) -> bool:
	return event.is_action_pressed(TOGGLE_ACTION) and not event.is_echo()
