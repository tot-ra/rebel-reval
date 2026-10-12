class_name ReflectionOverlay
extends CanvasLayer

## Hingepuu reflection screen. R-1892: visual-first layout - pip gauges for
## pressures and trust, coloured mark chips and three icon cards for the
## convictions. The full prose (recap + marks) is kept only as the accessible
## plain summary (tooltip + get_plain_summary_text), not as a visible paragraph.

signal closed
signal conviction_chosen(option_id: String)

const MenuStyle := preload("res://scripts/ui/pause_menu_style.gd")
const CARD_ICON_SIZE := 96.0

var _root: MarginContainer
var _dim: ColorRect
var _panel: PanelContainer
var _intro_label: Label
var _gauges_box: HBoxContainer
var _plain_summary_label: Label
var _marks_box: HFlowContainer
var _natural_label: Label
var _psyche_label: Label
var _loci_label: Label
var _options_box: HBoxContainer
var _snapshot: Dictionary = {}


func _ready() -> void:
	layer = 23
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# WHY: stay out of modal_input_overlay until present(); a permanent group
	# membership permanently blocks Player locomotion via _movement_blocked().
	_build_ui()


func is_open() -> bool:
	return visible


func present(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	visible = true
	add_to_group(&"modal_input_overlay")
	MenuStyle.apply_overlay(_root, _panel, _dim)
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	remove_from_group(&"modal_input_overlay")
	_snapshot = {}
	_clear_options()
	closed.emit()


func get_plain_summary_text() -> String:
	return String(_plain_summary_label.text) if _plain_summary_label != null else ""


func get_mark_labels() -> Array[String]:
	var labels: Array[String] = []
	if _marks_box == null:
		return labels
	for child in _marks_box.get_children():
		if child.has_meta(&"mark_label"):
			labels.append(String(child.get_meta(&"mark_label")))
	return labels


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_root = MarginContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_root.add_theme_constant_override("margin_" + side, 36)
	add_child(_root)

	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel.custom_minimum_size = Vector2(720, 0)
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var header := Label.new()
	header.text = "Hingepuu"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuStyle.apply_title(header, 28)
	layout.add_child(header)

	_intro_label = Label.new()
	_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_label.add_theme_font_size_override("font_size", 15)
	MenuStyle.apply_muted(_intro_label)
	layout.add_child(_intro_label)

	_gauges_box = HBoxContainer.new()
	_gauges_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_gauges_box.add_theme_constant_override("separation", 28)
	# Tooltip carries the plain summary so mouse users can still read the prose.
	_gauges_box.mouse_filter = Control.MOUSE_FILTER_PASS
	layout.add_child(_gauges_box)

	_marks_box = HFlowContainer.new()
	_marks_box.alignment = FlowContainer.ALIGNMENT_CENTER
	_marks_box.add_theme_constant_override("h_separation", 8)
	_marks_box.add_theme_constant_override("v_separation", 6)
	layout.add_child(_marks_box)

	# Accessible prose. Hidden: it repeats the gauges and chips word for word.
	_plain_summary_label = Label.new()
	_plain_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_plain_summary_label.visible = false
	layout.add_child(_plain_summary_label)

	_natural_label = _make_small_label()
	layout.add_child(_natural_label)
	_psyche_label = _make_small_label()
	layout.add_child(_psyche_label)
	_loci_label = _make_small_label()
	layout.add_child(_loci_label)

	layout.add_child(HSeparator.new())

	_options_box = HBoxContainer.new()
	_options_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_options_box.add_theme_constant_override("separation", 14)
	layout.add_child(_options_box)


func _make_small_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	MenuStyle.apply_muted(label)
	label.visible = false
	return label


func _refresh() -> void:
	_intro_label.text = String(_snapshot.get("intro", ""))
	_intro_label.visible = not _intro_label.text.is_empty()
	_plain_summary_label.text = String(_snapshot.get("plain_summary", ""))
	_refresh_gauges(_snapshot.get("gauges", []) as Array)
	_refresh_marks(_snapshot.get("marks", []) as Array)
	_refresh_natural(_snapshot)
	_refresh_psyche(_snapshot)
	_refresh_loci(_snapshot)
	_refresh_options(_snapshot.get("options", []) as Array)
	call_deferred("_seed_option_focus")


func _refresh_gauges(gauges: Array) -> void:
	for child in _gauges_box.get_children():
		child.queue_free()
	_gauges_box.tooltip_text = _plain_summary_label.text
	for gauge_variant in gauges:
		if not gauge_variant is Dictionary:
			continue
		var gauge := gauge_variant as Dictionary
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		column.mouse_filter = Control.MOUSE_FILTER_PASS
		column.tooltip_text = _plain_summary_label.text
		var name_label := Label.new()
		name_label.text = String(gauge.get("label", ""))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 13)
		MenuStyle.apply_muted(name_label)
		column.add_child(name_label)
		var pips := PipGauge.new()
		pips.setup(
			int(gauge.get("value", 0)),
			int(gauge.get("min", 0)),
			int(gauge.get("max", 3)),
			gauge.get("color", Color.WHITE) as Color
		)
		pips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(pips)
		_gauges_box.add_child(column)
	_gauges_box.visible = _gauges_box.get_child_count() > 0


func _refresh_natural(snapshot: Dictionary) -> void:
	if not bool(snapshot.get("natural_enabled", false)):
		_natural_label.text = ""
		_natural_label.visible = false
		return
	var aspects: Array = snapshot.get("natural_aspects", []) as Array
	if aspects.is_empty():
		_natural_label.text = ""
		_natural_label.visible = false
		return
	var parts := PackedStringArray()
	parts.append(
		"NATURAL - %d point(s) unspent" % int(snapshot.get("natural_unspent_points", 0))
	)
	for aspect_variant in aspects:
		if not aspect_variant is Dictionary:
			continue
		var aspect := aspect_variant as Dictionary
		var display := String(aspect.get("display", aspect.get("id", "")))
		var rank := int(aspect.get("rank", 0))
		var effective_rank := int(aspect.get("effective_rank", rank))
		var rank_text := str(rank)
		if effective_rank != rank:
			rank_text += " (effective %d)" % effective_rank
		parts.append("%s: %s" % [display, rank_text])
	_natural_label.text = "  |  ".join(parts)
	_natural_label.visible = true


func _refresh_psyche(snapshot: Dictionary) -> void:
	var states: Array = snapshot.get("psyche_states", []) as Array
	var parts := PackedStringArray()
	for state_variant in states:
		if not state_variant is Dictionary:
			continue
		var state := state_variant as Dictionary
		var line := "%s (intensity %d)" % [
			String(state.get("id", "")), int(state.get("intensity", 1))
		]
		var source_beat := String(state.get("source_beat", ""))
		if not source_beat.is_empty():
			line += " - source: %s" % source_beat
		parts.append(line)
	_psyche_label.text = "Psyche: " + ", ".join(parts) if not parts.is_empty() else ""
	_psyche_label.visible = not parts.is_empty()


func _refresh_loci(snapshot: Dictionary) -> void:
	# WHY: loci are the future explorable host (P7-011); until NATURAL is on they
	# are not player-facing, so the slice reflection does not list them.
	_loci_label.text = ""
	_loci_label.visible = false
	if not bool(snapshot.get("natural_enabled", false)):
		return
	var names := PackedStringArray()
	for locus_variant in snapshot.get("hingepuu_loci", []) as Array:
		if not locus_variant is Dictionary:
			continue
		var locus_id := String((locus_variant as Dictionary).get("id", ""))
		if not locus_id.is_empty():
			names.append(locus_id.get_slice(".", locus_id.get_slice_count(".") - 1).capitalize())
	if names.is_empty():
		return
	_loci_label.text = "Loci: " + ", ".join(names)
	_loci_label.visible = true


func _refresh_marks(marks: Array) -> void:
	for child in _marks_box.get_children():
		_marks_box.remove_child(child)
		child.queue_free()
	for mark_variant in marks:
		if not mark_variant is Dictionary:
			continue
		var mark := mark_variant as Dictionary
		var text := String(mark.get("label", ""))
		var color: Color = mark.get("color", Color.WHITE)
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(color, 0.16)
		style.border_color = Color(color, 0.85)
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		chip.add_theme_stylebox_override("panel", style)
		chip.set_meta(&"mark_label", text)
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", color.lightened(0.25))
		chip.add_child(label)
		_marks_box.add_child(chip)
	# No placeholder: a bare tree simply shows no chips.
	_marks_box.visible = _marks_box.get_child_count() > 0


func _refresh_options(options: Array) -> void:
	_clear_options()
	for option_variant in options:
		if not option_variant is Dictionary:
			continue
		var option := option_variant as Dictionary
		var option_id := String(option.get("id", ""))
		var button := Button.new()
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(200, 196)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# The one-line flavour moves to the tooltip; the card shows icon, name, effect.
		button.tooltip_text = "%s - %s\n%s" % [
			String(option.get("title", "")),
			String(option.get("summary", "")),
			String(option.get("plain_text", "")),
		]
		button.set_meta(&"option_id", option_id)
		button.pressed.connect(func() -> void: conviction_chosen.emit(option_id))
		button.add_child(_build_card_content(option))
		_options_box.add_child(button)
	_wire_option_focus_neighbors()


func _build_card_content(option: Dictionary) -> Control:
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_path := String(option.get("icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(CARD_ICON_SIZE, CARD_ICON_SIZE)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)

	var title := Label.new()
	title.text = String(option.get("title", ""))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuStyle.apply_title(title, 20)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)

	var effect := Label.new()
	effect.text = String(option.get("effect_label", ""))
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.add_theme_font_size_override("font_size", 14)
	effect.add_theme_color_override("font_color", MenuStyle.TEXT)
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(effect)
	return content


func _wire_option_focus_neighbors() -> void:
	if _options_box == null:
		return
	var buttons: Array[Button] = []
	for child in _options_box.get_children():
		if child is Button:
			buttons.append(child as Button)
	for index in buttons.size():
		var button: Button = buttons[index]
		if index > 0:
			var previous: Button = buttons[index - 1]
			button.focus_neighbor_left = button.get_path_to(previous)
			button.focus_neighbor_top = button.get_path_to(previous)
			previous.focus_neighbor_right = previous.get_path_to(button)
			previous.focus_neighbor_bottom = previous.get_path_to(button)


func focus_conviction(option_id: String) -> void:
	if _options_box == null:
		return
	for child in _options_box.get_children():
		if child is Button and String(child.get_meta(&"option_id", "")) == option_id:
			(child as Button).grab_focus()
			return


func _seed_option_focus() -> void:
	if _options_box == null:
		return
	for child in _options_box.get_children():
		if child is Button:
			(child as Button).grab_focus()
			return


func _clear_options() -> void:
	if _options_box == null:
		return
	for child in _options_box.get_children():
		_options_box.remove_child(child)
		child.queue_free()


## Row of round pips. For a range that crosses zero (trust -3..+3) the pips fill
## outward from a centre tick, so negative and positive read at a glance.
class PipGauge:
	extends Control

	const PIP_RADIUS := 7.0
	const PIP_GAP := 6.0

	var value := 0
	var min_value := 0
	var max_value := 3
	var color := Color.WHITE

	func setup(new_value: int, new_min: int, new_max: int, new_color: Color) -> void:
		value = new_value
		min_value = new_min
		max_value = new_max
		color = new_color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(_width(), PIP_RADIUS * 2.0 + 2.0)
		queue_redraw()

	func _slot_values() -> Array[int]:
		var slots: Array[int] = []
		for step in range(min_value, max_value + 1):
			if step == 0:
				continue
			slots.append(step)
		return slots

	func _width() -> float:
		var count := _slot_values().size()
		var centre := 10.0 if min_value < 0 else 0.0
		return count * PIP_RADIUS * 2.0 + maxf(0.0, count - 1) * PIP_GAP + centre

	func _draw() -> void:
		var x := PIP_RADIUS
		var y := size.y * 0.5
		var negative := Color(0.86, 0.36, 0.3, 1.0)
		for step in _slot_values():
			if min_value < 0 and step == 1:
				var tick_x := x - PIP_RADIUS - 3.0
				draw_line(
					Vector2(tick_x, y - 8.0), Vector2(tick_x, y + 8.0), Color(MenuStyle.GOLD, 0.7), 2.0
				)
				x += 10.0
			var filled := (step > 0 and value >= step) or (step < 0 and value <= step)
			var tint := negative if step < 0 else color
			if filled:
				draw_circle(Vector2(x, y), PIP_RADIUS, tint)
			else:
				draw_circle(Vector2(x, y), PIP_RADIUS, Color(tint, 0.15))
				draw_arc(Vector2(x, y), PIP_RADIUS - 0.5, 0.0, TAU, 20, Color(tint, 0.6), 1.0, true)
			x += PIP_RADIUS * 2.0 + PIP_GAP
