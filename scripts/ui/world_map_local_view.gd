class_name WorldMapLocalView
extends Control

## Focused local-map presentation owned by WorldMapOverlay. The view receives
## compiled minimap data and owns only texture/marker rendering, not map state.

const PANEL_SIZE := Vector2(820, 600)
const MARKER_SIZE := Vector2(16, 16)
const FALLBACK_DISPLAY_SIZE := Vector2(PANEL_SIZE.x - 40.0, 420.0)

var _current_scene_id: StringName = &""
var _local_map: MinimapHud
var _local_texture: ImageTexture

var _texture_rect: TextureRect
var _marker: Panel
var _unavailable: Label


func _ready() -> void:
	_build_ui()
	refresh()
	set_process(true)


func _process(_delta: float) -> void:
	if visible:
		update_marker()


func configure(local_map: MinimapHud, current_scene_id: StringName) -> void:
	_local_map = local_map
	_current_scene_id = current_scene_id
	if is_node_ready():
		refresh()


func refresh() -> void:
	if _texture_rect == null:
		return
	_local_texture = null
	_texture_rect.texture = null
	var available := _has_local_map_data()
	_unavailable.visible = not available
	_texture_rect.visible = available
	_marker.visible = available
	if not available:
		return

	var image := _local_map.get_local_map_image()
	if image == null or image.is_empty():
		_unavailable.visible = true
		_texture_rect.visible = false
		_marker.visible = false
		return

	_local_texture = ImageTexture.create_from_image(image)
	_texture_rect.texture = _local_texture
	var area := size
	if area.x < 8.0 or area.y < 8.0:
		area = FALLBACK_DISPLAY_SIZE
	var scale_factor := minf(area.x / float(image.get_width()), area.y / float(image.get_height()))
	var display_size := Vector2(image.get_width(), image.get_height()) * scale_factor
	_texture_rect.position = (area - display_size) * 0.5
	_texture_rect.size = display_size
	update_marker()


func update_marker() -> void:
	if _marker == null or _texture_rect == null:
		return
	var available := visible and _has_local_map_data() and _texture_rect.texture != null
	if not available:
		_marker.visible = false
		return
	var normalized := _local_map.get_player_map_position()
	if normalized.x < 0.0 or normalized.y < 0.0:
		_marker.visible = false
		return
	_marker.visible = true
	_marker.position = _texture_rect.position + normalized * _texture_rect.size - MARKER_SIZE * 0.5


func subtitle() -> String:
	if _local_map != null and is_instance_valid(_local_map):
		var location_name := _local_map.get_location_name()
		if not location_name.is_empty():
			return "You are here: %s" % location_name
	if not _current_scene_id.is_empty():
		return "You are here: %s" % LocationHud.display_name_for_scene(_current_scene_id)
	return "Current location is outside the active map registry."


func help_text() -> String:
	return "Your live position is marked in red. Choose Fast travel for connected districts. Press M or Escape to close."


func get_marker() -> Control:
	return _marker


func get_texture_rect() -> TextureRect:
	return _texture_rect


func _has_local_map_data() -> bool:
	return _local_map != null and is_instance_valid(_local_map) and _local_map.has_map_data()


func _build_ui() -> void:
	_texture_rect = TextureRect.new()
	_texture_rect.name = "LocalMapTexture"
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)

	_marker = Panel.new()
	_marker.name = "PlayerLocationMarker"
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.custom_minimum_size = MARKER_SIZE
	_marker.size = MARKER_SIZE
	_marker.add_theme_stylebox_override("panel", _marker_style())
	add_child(_marker)

	_unavailable = Label.new()
	_unavailable.name = "LocalMapUnavailable"
	_unavailable.text = "A local map is not available for this location."
	_unavailable.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unavailable.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unavailable.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_unavailable.add_theme_color_override("font_color", Color(0.68, 0.72, 0.76, 1.0))
	add_child(_unavailable)


func _marker_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.22, 0.18, 1.0)
	style.border_color = Color(1.0, 0.92, 0.72, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(MARKER_SIZE.x * 0.5))
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
	style.shadow_size = 4
	return style
