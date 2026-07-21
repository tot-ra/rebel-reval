class_name WorldMapOverlayBuilder
extends RefCounted

## Builds the world-map overlay node tree so WorldMapOverlay stays focused on
## map state, mode changes, and travel behavior.

const LocalView := preload("res://scripts/ui/world_map_local_view.gd")
const FastTravelView := preload("res://scripts/ui/world_map_fast_travel_view.gd")

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

	var local_view := LocalView.new()
	local_view.name = "LocalMapHost"
	local_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	local_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	local_view.custom_minimum_size = Vector2(0, 420)
	layout.add_child(local_view)

	var fast_travel_view := FastTravelView.new()
	fast_travel_view.name = "GraphHost"
	fast_travel_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fast_travel_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fast_travel_view.custom_minimum_size = Vector2(0, 420)
	layout.add_child(fast_travel_view)

	var help := Label.new()
	help.name = "HelpLabel"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(0.68, 0.72, 0.76, 1.0))
	layout.add_child(help)

	return {
		"title": title,
		"subtitle": subtitle,
		"local_view": local_view,
		"fast_travel_view": fast_travel_view,
		"local_tab": local_tab,
		"fast_travel_tab": fast_travel_tab,
		"close_button": close_button,
		"help": help,
	}
