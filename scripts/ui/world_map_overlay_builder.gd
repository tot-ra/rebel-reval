class_name WorldMapOverlayBuilder
extends RefCounted

## Builds the world-map overlay node tree so WorldMapOverlay stays focused on
## map state, mode changes, and travel behavior.

const PANEL_SIZE := Vector2(820, 600)
const NODE_SIZE := Vector2(132, 44)
const LOCAL_MARKER_SIZE := Vector2(16, 16)


static func build(host: CanvasLayer, callbacks: Dictionary) -> Dictionary:
	var root := Control.new()
	root.name = "WorldMapRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.05, 0.08, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "WorldMapPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = PANEL_SIZE
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)

	var title := Label.new()
	title.name = "Title"
	title.text = "Map"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.92, 0.82, 0.56, 1.0))
	titles.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.82, 0.86, 0.95))
	titles.add_child(subtitle)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	close_button.pressed.connect(callbacks["close"])
	header.add_child(close_button)

	var tabs := HBoxContainer.new()
	tabs.name = "MapOptions"
	tabs.add_theme_constant_override("separation", 8)
	layout.add_child(tabs)

	var local_tab := Button.new()
	local_tab.name = "LocalMapButton"
	local_tab.text = "Local map"
	local_tab.tooltip_text = "Show your position in the current location"
	local_tab.pressed.connect(callbacks["show_local_map"])
	tabs.add_child(local_tab)

	var fast_travel_tab := Button.new()
	fast_travel_tab.name = "FastTravelButton"
	fast_travel_tab.text = "Fast travel"
	fast_travel_tab.tooltip_text = "Travel to a connected district"
	fast_travel_tab.pressed.connect(callbacks["show_fast_travel"])
	tabs.add_child(fast_travel_tab)

	var local_host := Control.new()
	local_host.name = "LocalMapHost"
	local_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	local_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	local_host.custom_minimum_size = Vector2(0, 420)
	layout.add_child(local_host)

	var local_texture_rect := TextureRect.new()
	local_texture_rect.name = "LocalMapTexture"
	local_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	local_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	local_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	local_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	local_host.add_child(local_texture_rect)

	var local_marker := Panel.new()
	local_marker.name = "PlayerLocationMarker"
	local_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	local_marker.custom_minimum_size = LOCAL_MARKER_SIZE
	local_marker.size = LOCAL_MARKER_SIZE
	local_marker.add_theme_stylebox_override("panel", _local_marker_style())
	local_host.add_child(local_marker)

	var local_unavailable := Label.new()
	local_unavailable.name = "LocalMapUnavailable"
	local_unavailable.text = "A local map is not available for this location."
	local_unavailable.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	local_unavailable.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	local_unavailable.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	local_unavailable.add_theme_color_override("font_color", Color(0.68, 0.72, 0.76, 1.0))
	local_host.add_child(local_unavailable)

	var graph_host := Control.new()
	graph_host.name = "GraphHost"
	graph_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_host.custom_minimum_size = Vector2(0, 420)
	graph_host.draw.connect(callbacks["draw_connections"])
	layout.add_child(graph_host)

	var help := Label.new()
	help.name = "HelpLabel"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(0.68, 0.72, 0.76, 1.0))
	layout.add_child(help)

	return {
		"title": title,
		"subtitle": subtitle,
		"local_host": local_host,
		"local_texture_rect": local_texture_rect,
		"local_marker": local_marker,
		"local_unavailable": local_unavailable,
		"graph_host": graph_host,
		"local_tab": local_tab,
		"fast_travel_tab": fast_travel_tab,
		"close_button": close_button,
		"help": help,
	}


static func _local_marker_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.22, 0.18, 1.0)
	style.border_color = Color(1.0, 0.92, 0.72, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(LOCAL_MARKER_SIZE.x * 0.5))
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
	style.shadow_size = 4
	return style
