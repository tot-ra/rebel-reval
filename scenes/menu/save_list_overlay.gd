extends Control

## Modal overlay that lists all save slots and lets the player load one.
## Spawned by load_label.gd when the user clicks "Load" in the main menu.

const PANEL_WIDTH := 600.0
const PANEL_HEIGHT := 500.0
const ENTRY_HEIGHT := 72.0
const ENTRY_MARGIN := 6.0
const SCROLLBAR_WIDTH := 8.0

const PHASE_LABELS: Dictionary = {
	"phase.prologue_day": "Prologue - Day",
	"phase.investigation_morning": "Investigation - Morning",
	"phase.investigation_night": "Investigation - Night",
	"phase.consequence_night": "Consequence - Night",
	"phase.reflection_morning": "Reflection - Morning",
}

signal save_selected(slot: int)


func _ready() -> void:
	_build_ui()
	_populate_entries()


func _build_ui() -> void:
	# Dim background - click to close.
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)

	# Centre panel.
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# Title.
	var title := Label.new()
	title.name = "Title"
	title.text = "Load Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.name = "Sep"
	vbox.add_child(sep)

	# Scroll container for entries.
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	vbox.add_child(scroll)

	var entry_list := VBoxContainer.new()
	entry_list.name = "EntryList"
	entry_list.unique_name_in_owner = true
	entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(entry_list)

	# Back button row at the bottom.
	var btn_row := HBoxContainer.new()
	btn_row.name = "BtnRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var back_btn := Button.new()
	back_btn.name = "BackBtn"
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(160, 40)
	back_btn.pressed.connect(_close)
	btn_row.add_child(back_btn)

	# Default focus for keyboard navigation.
	back_btn.grab_focus.call_deferred()


func _populate_entries() -> void:
	var saves: Array[Dictionary] = SessionState.list_saves()
	var entry_list: VBoxContainer = %EntryList if has_node("%EntryList") else _find_entry_list()

	if saves.is_empty():
		_close()
		return

	for save in saves:
		var entry := _create_entry(save)
		entry_list.add_child(entry)

	# Focus the first load button for keyboard navigation.
	if entry_list.get_child_count() > 0:
		var first_entry := entry_list.get_child(0)
		var first_btn := first_entry.get_node_or_null("HBox/LoadBtn") as Button
		if first_btn != null:
			first_btn.grab_focus.call_deferred()


func _create_entry(save: Dictionary) -> PanelContainer:
	var slot: int = save["slot"]
	var saved_at: int = save["saved_at_unix"]
	var phase: String = save["phase"]
	var location_id: String = save["location_id"]

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, ENTRY_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	# Slot badge.
	var badge := Label.new()
	badge.name = "SlotBadge"
	badge.text = "Slot %d" % (slot + 1)
	badge.custom_minimum_size = Vector2(80, 0)
	badge.add_theme_font_size_override("font_size", 20)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(badge)

	# Info column (phase + timestamp + location).
	var info := VBoxContainer.new()
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var phase_label := Label.new()
	phase_label.name = "PhaseLabel"
	phase_label.text = PHASE_LABELS.get(phase, phase)
	phase_label.add_theme_font_size_override("font_size", 20)
	info.add_child(phase_label)

	var detail_label := Label.new()
	detail_label.name = "DetailLabel"
	detail_label.text = _format_timestamp(saved_at)
	detail_label.add_theme_font_size_override("font_size", 14)
	detail_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info.add_child(detail_label)

	if not location_id.is_empty():
		var loc_label := Label.new()
		loc_label.name = "LocationLabel"
		loc_label.text = location_id.replace("_", " ").capitalize()
		loc_label.add_theme_font_size_override("font_size", 14)
		loc_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
		info.add_child(loc_label)

	# Load button.
	var load_btn := Button.new()
	load_btn.name = "LoadBtn"
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(100, 40)
	load_btn.pressed.connect(_on_load_pressed.bind(slot))
	hbox.add_child(load_btn)

	return panel


func _on_load_pressed(slot: int) -> void:
	save_selected.emit(slot)
	_close()


func _close() -> void:
	queue_free()


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close()


func _find_entry_list() -> VBoxContainer:
	return get_node("%EntryList") if has_node("%EntryList") else get_node("Panel/Margin/VBox/Scroll/EntryList")


func _format_timestamp(unix: int) -> String:
	if unix <= 0:
		return "Unknown date"
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]
