class_name EquipmentSilhouette
extends Control

## Human silhouette with equipment drop zones for the bag overlay.
## Drawn as a leather paper-doll with brass fittings to match InventoryUiTheme.

signal slot_pressed(slot: StringName)

const InventoryUiThemeScene := preload("res://scripts/inventory/inventory_ui_theme.gd")

const SLOT_ORDER: Array[StringName] = [&"head", &"back", &"left_hand", &"right_hand"]

const SLOT_LABELS := {
	&"head": "Head",
	&"back": "Back",
	&"left_hand": "Left hand",
	&"right_hand": "Right hand",
}

var _slot_rects: Dictionary = {}
var _hover_slot: StringName = &""
var _equipped: Dictionary[StringName, StringName] = {}
var _slot_accepts_drop: Callable = Callable()
var _slot_drop: Callable = Callable()
var _item_label: Callable = Callable()
var _item_short_label: Callable = Callable()
var _drag_kind_bag: StringName = &"bag"
var _drag_kind_equipped: StringName = &"equipped"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Drag items onto slots. Click a worn slot to stow it in the bag."
	resized.connect(_rebuild_slot_rects)
	_rebuild_slot_rects()


func configure_drop_handlers(
	accepts_drop: Callable,
	on_drop: Callable,
	item_label: Callable,
	item_short_label: Callable = Callable(),
	drag_kind_bag: StringName = &"bag",
	drag_kind_equipped: StringName = &"equipped"
) -> void:
	_slot_accepts_drop = accepts_drop
	_slot_drop = on_drop
	_item_label = item_label
	_item_short_label = item_short_label
	_drag_kind_bag = drag_kind_bag
	_drag_kind_equipped = drag_kind_equipped


func set_equipped(slots: Dictionary) -> void:
	_equipped = slots
	queue_redraw()


func _rebuild_slot_rects() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	# Wider slots keep item names readable without covering the body silhouette.
	var slot_size := Vector2(w * 0.34, h * 0.145)
	_slot_rects = {
		&"head": Rect2(Vector2(w * 0.5 - slot_size.x * 0.5, h * 0.01), slot_size),
		&"back": Rect2(Vector2(w * 0.5 - slot_size.x * 0.5, h * 0.36), slot_size),
		&"left_hand": Rect2(Vector2(w * 0.01, h * 0.22), slot_size),
		&"right_hand": Rect2(Vector2(w * 0.65, h * 0.22), slot_size),
	}
	queue_redraw()


func _draw() -> void:
	_draw_body()
	_draw_slots()


func _draw_body() -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var fill := InventoryUiThemeScene.SILHOUETTE_FILL
	var stroke := InventoryUiThemeScene.SILHOUETTE_STROKE
	var brass := InventoryUiThemeScene.BRASS

	# Soft leather stand-in so the doll reads as a craft bench mannequin, not a UI stick figure.
	draw_circle(Vector2(cx + 1.5, h * 0.13 + 1.5), h * 0.078, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(Vector2(cx, h * 0.13), h * 0.075, fill)
	draw_arc(Vector2(cx, h * 0.13), h * 0.075, 0.0, TAU, 24, brass, 1.5)

	var torso := Rect2(cx - w * 0.13, h * 0.22, w * 0.26, h * 0.30)
	draw_rect(Rect2(torso.position + Vector2(2, 2), torso.size), Color(0.0, 0.0, 0.0, 0.22))
	draw_rect(torso, fill)
	draw_rect(torso, stroke, false, 2.0)
	# Apron band: smithing context without covering slot labels.
	var apron := Rect2(cx - w * 0.11, h * 0.34, w * 0.22, h * 0.14)
	draw_rect(apron, fill.darkened(0.12))
	draw_line(
		Vector2(apron.position.x, apron.position.y),
		Vector2(apron.end.x, apron.position.y),
		brass,
		1.5
	)

	var shoulder_y := h * 0.26
	draw_line(Vector2(cx - w * 0.13, shoulder_y), Vector2(w * 0.10, h * 0.30), fill, 9.0)
	draw_line(Vector2(cx + w * 0.13, shoulder_y), Vector2(w * 0.90, h * 0.30), fill, 9.0)
	draw_circle(Vector2(w * 0.10, h * 0.30), 7.0, fill)
	draw_circle(Vector2(w * 0.90, h * 0.30), 7.0, fill)
	draw_arc(Vector2(w * 0.10, h * 0.30), 7.0, 0.0, TAU, 16, brass, 1.2)
	draw_arc(Vector2(w * 0.90, h * 0.30), 7.0, 0.0, TAU, 16, brass, 1.2)

	var hip_y := h * 0.52
	draw_line(Vector2(cx - w * 0.07, hip_y), Vector2(cx - w * 0.10, h * 0.88), fill, 11.0)
	draw_line(Vector2(cx + w * 0.07, hip_y), Vector2(cx + w * 0.10, h * 0.88), fill, 11.0)


func _draw_slots() -> void:
	for slot: StringName in SLOT_ORDER:
		if not _slot_rects.has(slot):
			continue
		var rect: Rect2 = _slot_rects[slot]
		var occupied := _equipped.has(slot) and not String(_equipped[slot]).is_empty()
		var base := InventoryUiThemeScene.SLOT_EMPTY
		if occupied:
			base = InventoryUiThemeScene.SLOT_FILLED
		if slot == _hover_slot:
			base = base.lightened(0.14)
		draw_rect(rect, base)
		var border := (
			InventoryUiThemeScene.BRASS_BRIGHT if slot == _hover_slot
			else InventoryUiThemeScene.BRASS
		)
		draw_rect(rect, border, false, 1.8)

		var slot_name := String(SLOT_LABELS.get(slot, slot))
		var label := slot_name
		if occupied:
			if _item_short_label.is_valid():
				label = String(_item_short_label.call(_equipped[slot]))
			elif _item_label.is_valid():
				label = String(_item_label.call(_equipped[slot]))
		_draw_slot_label(rect, slot_name if occupied else "", label)


func _draw_slot_label(rect: Rect2, caption: String, text: String) -> void:
	var font := ThemeDB.fallback_font
	var caption_size := 9
	var font_size := 11
	var max_width := rect.size.x - 8.0
	var lines := _wrap_label(text, max_width, font, font_size)
	var line_height := font.get_height(font_size) + 1
	var caption_height := 0.0
	if not caption.is_empty():
		caption_height = font.get_height(caption_size) + 1.0
	var content_height := caption_height + lines.size() * line_height
	var y := rect.position.y + maxf(4.0, (rect.size.y - content_height) * 0.5)
	if not caption.is_empty():
		var caption_width := font.get_string_size(
			caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size
		).x
		var caption_x := rect.position.x + (rect.size.x - caption_width) * 0.5
		draw_string(
			font,
			Vector2(caption_x, y + font.get_ascent(caption_size)),
			caption,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			caption_size,
			InventoryUiThemeScene.INK_MUTED
		)
		y += caption_height
	var remaining := rect.end.y - y - 4.0
	var max_lines := maxi(1, int(remaining / line_height))
	if lines.size() > max_lines:
		lines = lines.slice(0, max_lines)
	for line in lines:
		var line_width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x := rect.position.x + (rect.size.x - line_width) * 0.5
		draw_string(
			font,
			Vector2(x, y + font.get_ascent(font_size)),
			line,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			InventoryUiThemeScene.PARCHMENT
		)
		y += line_height


func _wrap_label(text: String, max_width: float, font: Font, font_size: int) -> PackedStringArray:
	var words := text.split(" ", false)
	if words.is_empty():
		return PackedStringArray([text])
	var lines: PackedStringArray = []
	var current := words[0]
	for word_index in range(1, words.size()):
		var candidate := "%s %s" % [current, words[word_index]]
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
			current = candidate
		else:
			lines.append(current)
			current = words[word_index]
	lines.append(current)
	return lines


func _slot_at(position: Vector2) -> StringName:
	for slot: StringName in SLOT_ORDER:
		var rect: Rect2 = _slot_rects.get(slot, Rect2())
		if rect.has_point(position):
			return slot
	return &""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var next_slot := _slot_at(motion.position)
		if next_slot != _hover_slot:
			_hover_slot = next_slot
			_update_hover_tooltip(next_slot)
			queue_redraw()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			var slot := _slot_at(button.position)
			if not slot.is_empty():
				slot_pressed.emit(slot)


func _get_drag_data(at_position: Vector2) -> Variant:
	var slot := _slot_at(at_position)
	if slot.is_empty() or not _equipped.has(slot):
		return null
	var item_id: StringName = _equipped[slot]
	if String(item_id).is_empty():
		return null
	var preview := Label.new()
	preview.text = _item_label.call(item_id) if _item_label.is_valid() else String(item_id)
	set_drag_preview(preview)
	return {"kind": _drag_kind_equipped, "slot": slot, "item_id": item_id}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var slot := _slot_at(at_position)
	if slot.is_empty() or not data is Dictionary:
		return false
	if not _slot_accepts_drop.is_valid():
		return false
	return bool(_slot_accepts_drop.call(slot, data))


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var slot := _slot_at(at_position)
	if slot.is_empty() or not data is Dictionary:
		return
	if _slot_drop.is_valid():
		_slot_drop.call(slot, data)
	_hover_slot = &""
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		if not _hover_slot.is_empty():
			_hover_slot = &""
			tooltip_text = "Drag items onto slots. Click a worn slot to stow it in the bag."
			queue_redraw()


func _update_hover_tooltip(slot: StringName) -> void:
	if slot.is_empty():
		tooltip_text = "Drag items onto slots. Click a worn slot to stow it in the bag."
		return
	var slot_name := String(SLOT_LABELS.get(slot, slot))
	if _equipped.has(slot) and not String(_equipped[slot]).is_empty() and _item_label.is_valid():
		tooltip_text = "%s: %s\nClick to stow in the bag." % [
			slot_name,
			String(_item_label.call(_equipped[slot])),
		]
		return
	tooltip_text = "%s slot\nDrop a matching item here." % slot_name
