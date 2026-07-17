class_name EquipmentSilhouette
extends Control

## Human silhouette with equipment drop zones for the bag overlay.
## Hand slots accept drag-and-drop; head and back accept click-to-unequip.

signal slot_pressed(slot: StringName)

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
var _drag_kind_bag: StringName = &"bag"
var _drag_kind_equipped: StringName = &"equipped"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Drag items onto hand slots. Click a worn slot to stow it in the bag."
	resized.connect(_rebuild_slot_rects)
	_rebuild_slot_rects()


func configure_drop_handlers(
	accepts_drop: Callable,
	on_drop: Callable,
	item_label: Callable,
	drag_kind_bag: StringName = &"bag",
	drag_kind_equipped: StringName = &"equipped"
) -> void:
	_slot_accepts_drop = accepts_drop
	_slot_drop = on_drop
	_item_label = item_label
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
	var slot_size := Vector2(w * 0.24, h * 0.11)
	_slot_rects = {
		&"head": Rect2(Vector2(w * 0.5 - slot_size.x * 0.5, h * 0.02), slot_size),
		&"back": Rect2(Vector2(w * 0.5 - slot_size.x * 0.5, h * 0.34), slot_size),
		&"left_hand": Rect2(Vector2(w * 0.02, h * 0.24), slot_size),
		&"right_hand": Rect2(Vector2(w * 0.74, h * 0.24), slot_size),
	}
	queue_redraw()


func _draw() -> void:
	_draw_body()
	_draw_slots()


func _draw_body() -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var fill := Color(0.30, 0.33, 0.38, 0.92)
	var stroke := Color(0.18, 0.20, 0.24, 0.95)

	draw_circle(Vector2(cx, h * 0.13), h * 0.075, fill)
	draw_arc(Vector2(cx, h * 0.13), h * 0.075, 0.0, TAU, 24, stroke, 2.0)

	var torso := Rect2(cx - w * 0.13, h * 0.22, w * 0.26, h * 0.30)
	draw_rect(torso, fill)
	draw_rect(torso, stroke, false, 2.0)

	var shoulder_y := h * 0.26
	draw_line(Vector2(cx - w * 0.13, shoulder_y), Vector2(w * 0.10, h * 0.30), fill, 9.0)
	draw_line(Vector2(cx + w * 0.13, shoulder_y), Vector2(w * 0.90, h * 0.30), fill, 9.0)
	draw_circle(Vector2(w * 0.10, h * 0.30), 7.0, fill)
	draw_circle(Vector2(w * 0.90, h * 0.30), 7.0, fill)

	var hip_y := h * 0.52
	draw_line(Vector2(cx - w * 0.07, hip_y), Vector2(cx - w * 0.10, h * 0.88), fill, 11.0)
	draw_line(Vector2(cx + w * 0.07, hip_y), Vector2(cx + w * 0.10, h * 0.88), fill, 11.0)


func _draw_slots() -> void:
	for slot: StringName in SLOT_ORDER:
		if not _slot_rects.has(slot):
			continue
		var rect: Rect2 = _slot_rects[slot]
		var occupied := _equipped.has(slot) and not String(_equipped[slot]).is_empty()
		var base := Color(0.16, 0.18, 0.22, 0.82)
		if occupied:
			base = Color(0.42, 0.48, 0.56, 0.92)
		if slot == _hover_slot:
			base = base.lightened(0.16)
		draw_rect(rect, base)
		draw_rect(rect, Color(0.72, 0.76, 0.82, 0.95), false, 1.5)

		var label := String(SLOT_LABELS.get(slot, slot))
		if occupied and _item_label.is_valid():
			label = String(_item_label.call(_equipped[slot]))
		_draw_wrapped_label(rect, label)


func _draw_wrapped_label(rect: Rect2, text: String) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 11
	var lines := _wrap_label(text, rect.size.x - 8.0, font, font_size)
	var line_height := font.get_height(font_size) + 1
	var total_height := lines.size() * line_height
	var y := rect.position.y + maxf(4.0, (rect.size.y - total_height) * 0.5)
	for line in lines:
		var line_width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x := rect.position.x + (rect.size.x - line_width) * 0.5
		draw_string(font, Vector2(x, y + font.get_ascent(font_size)), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.95, 0.96, 0.98))
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
			queue_redraw()
