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

const CAPTION_FONT_SIZE := 10

var _slot_rects: Dictionary = {}
## WHY: worn art uses real TextureRect children instead of draw_texture_rect.
## The Compatibility renderer batches the custom draw calls and paints the icon
## quad solid white when it follows the outlined slot rects.
var _slot_icons: Dictionary = {}
var _hover_slot: StringName = &""
var _equipped: Dictionary[StringName, StringName] = {}
var _highlight_slots: Array[StringName] = []
var _slot_accepts_drop: Callable = Callable()
var _slot_drop: Callable = Callable()
var _item_label: Callable = Callable()
var _item_short_label: Callable = Callable()
var _item_icon: Callable = Callable()
var _drag_kind_bag: StringName = &"bag"
var _drag_kind_equipped: StringName = &"equipped"
## WHY: Godot delivers the mouse-up that ends a successful drop to this Control.
## Treating that release as a slot click would immediately unequip the item we
## just wore, which feels like drag-to-equip is broken.
var _suppress_next_slot_click := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Drag items onto slots. Click a worn slot to stow it in the bag."
	for slot: StringName in SLOT_ORDER:
		var icon_rect := TextureRect.new()
		icon_rect.name = "%sIcon" % String(slot)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.visible = false
		add_child(icon_rect)
		_slot_icons[slot] = icon_rect
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


## Optional icon lookup so worn gear shows its painted art, not just a name.
func configure_icon_provider(item_icon: Callable) -> void:
	_item_icon = item_icon
	_sync_slot_icons()
	queue_redraw()


func set_equipped(slots: Dictionary) -> void:
	_equipped = slots
	_sync_slot_icons()
	queue_redraw()


func set_highlight_slots(slots: Array[StringName]) -> void:
	_highlight_slots = slots.duplicate()
	queue_redraw()


func _rebuild_slot_rects() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	# WHY: square slots flanking the mannequin in two columns. The old wide
	# rectangles sat on top of the body and buried it under labels.
	var side := minf(w * 0.30, h * 0.22)
	var slot_size := Vector2(side, side)
	var left_x := w * 0.015
	var right_x := w - side - w * 0.015
	var top_y := h * 0.10
	var bottom_y := h * 0.56
	_slot_rects = {
		&"head": Rect2(Vector2(left_x, top_y), slot_size),
		&"back": Rect2(Vector2(right_x, top_y), slot_size),
		&"left_hand": Rect2(Vector2(left_x, bottom_y), slot_size),
		&"right_hand": Rect2(Vector2(right_x, bottom_y), slot_size),
	}
	_sync_slot_icons()
	queue_redraw()


## Places worn art inside each slot, leaving the bottom caption strip free.
func _sync_slot_icons() -> void:
	for slot: StringName in SLOT_ORDER:
		var icon_rect: TextureRect = _slot_icons.get(slot)
		if icon_rect == null:
			continue
		var rect: Rect2 = _slot_rects.get(slot, Rect2())
		var item_id: StringName = _equipped.get(slot, &"")
		var texture := _icon_for(item_id) if not String(item_id).is_empty() else null
		icon_rect.texture = texture
		icon_rect.visible = texture != null and rect.size.x > 1.0
		if not icon_rect.visible:
			continue
		var strip_height := float(ThemeDB.fallback_font.get_height(CAPTION_FONT_SIZE)) + 2.0
		icon_rect.position = rect.position + Vector2(3.0, 3.0)
		icon_rect.size = Vector2(rect.size.x - 6.0, rect.size.y - strip_height - 6.0)


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
	var body_half := w * 0.115

	# Smith mannequin: shoulders, apron and belt read as a craft-bench dummy
	# rather than a UI stick figure, and it now owns the whole centre column.
	draw_circle(Vector2(cx + 1.5, h * 0.115 + 1.5), h * 0.062, Color(0.0, 0.0, 0.0, 0.30))
	draw_circle(Vector2(cx, h * 0.11), h * 0.060, fill)
	draw_arc(Vector2(cx, h * 0.11), h * 0.060, 0.0, TAU, 28, brass, 1.4)

	# Neck.
	draw_rect(Rect2(cx - w * 0.022, h * 0.165, w * 0.044, h * 0.035), fill.darkened(0.12))

	var torso := Rect2(cx - body_half, h * 0.195, body_half * 2.0, h * 0.34)
	draw_rect(Rect2(torso.position + Vector2(2, 3), torso.size), Color(0.0, 0.0, 0.0, 0.26))
	draw_rect(torso, fill)
	draw_rect(torso, stroke, false, 2.0)

	# Shoulder caps soften the boxy torso.
	draw_circle(Vector2(torso.position.x, h * 0.215), w * 0.030, fill)
	draw_circle(Vector2(torso.end.x, h * 0.215), w * 0.030, fill)

	# Leather apron over the chest, tied with a brass-buckled belt.
	var apron := Rect2(cx - w * 0.085, h * 0.255, w * 0.17, h * 0.245)
	draw_rect(apron, fill.darkened(0.16))
	draw_rect(apron, Color(brass.r, brass.g, brass.b, 0.35), false, 1.0)
	var belt := Rect2(cx - body_half, h * 0.455, body_half * 2.0, h * 0.030)
	draw_rect(belt, fill.darkened(0.30))
	draw_rect(
		Rect2(cx - w * 0.020, belt.position.y + 1.0, w * 0.040, belt.size.y - 2.0), brass
	)

	# Arms hang along the torso instead of reaching into the slot columns.
	var arm_width := w * 0.042
	draw_rect(Rect2(cx - body_half - arm_width, h * 0.215, arm_width, h * 0.28), fill.darkened(0.08))
	draw_rect(Rect2(cx + body_half, h * 0.215, arm_width, h * 0.28), fill.darkened(0.08))

	# Legs.
	var leg_width := w * 0.070
	draw_rect(Rect2(cx - body_half + 2.0, h * 0.535, leg_width, h * 0.36), fill)
	draw_rect(Rect2(cx + body_half - leg_width - 2.0, h * 0.535, leg_width, h * 0.36), fill)
	draw_rect(Rect2(cx - body_half + 2.0, h * 0.875, leg_width, h * 0.022), fill.darkened(0.30))
	draw_rect(
		Rect2(cx + body_half - leg_width - 2.0, h * 0.875, leg_width, h * 0.022),
		fill.darkened(0.30)
	)


func _draw_slots() -> void:
	for slot: StringName in SLOT_ORDER:
		if not _slot_rects.has(slot):
			continue
		var rect: Rect2 = _slot_rects[slot]
		var occupied := _equipped.has(slot) and not String(_equipped[slot]).is_empty()
		var highlighted := slot in _highlight_slots
		var base := InventoryUiThemeScene.SLOT_EMPTY
		if occupied:
			base = InventoryUiThemeScene.SLOT_FILLED
		if highlighted:
			base = InventoryUiThemeScene.LEATHER_VALID
		if slot == _hover_slot:
			base = base.lightened(0.14)
		draw_rect(rect, base)
		var border := (
			InventoryUiThemeScene.BRASS_BRIGHT if slot == _hover_slot or highlighted
			else InventoryUiThemeScene.BRASS
		)
		draw_rect(rect, border, false, 2.2 if highlighted else 1.8)

		var slot_name := String(SLOT_LABELS.get(slot, slot))
		var label := slot_name
		if occupied and _item_label.is_valid():
			label = String(_item_label.call(_equipped[slot]))
		elif occupied and _item_short_label.is_valid():
			label = String(_item_short_label.call(_equipped[slot]))
		# Caption rides a dark strip along the bottom edge so it stays readable
		# under the worn item art.
		_draw_slot_caption(rect, label, occupied)


func _icon_for(item_id: StringName) -> Texture2D:
	if not _item_icon.is_valid():
		return null
	var icon: Variant = _item_icon.call(item_id)
	return icon as Texture2D


func _draw_slot_caption(rect: Rect2, text: String, occupied: bool) -> void:
	var font := ThemeDB.fallback_font
	var font_size := CAPTION_FONT_SIZE
	var strip_height := float(font.get_height(font_size)) + 2.0
	var strip := Rect2(
		Vector2(rect.position.x + 1.0, rect.end.y - strip_height - 1.0),
		Vector2(rect.size.x - 2.0, strip_height)
	)
	if occupied:
		draw_rect(strip, Color(0.05, 0.03, 0.015, 0.72))
	var color := (
		InventoryUiThemeScene.PARCHMENT if occupied else InventoryUiThemeScene.INK_MUTED
	)
	# Shrink the caption a step or two rather than cropping "Forge hammer" to
	# "Forge"; only fall back to an ellipsis when even the small size overflows.
	var available := strip.size.x - 4.0
	var line := text
	while font_size > CAPTION_FONT_SIZE - 2:
		if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= available:
			break
		font_size -= 1
	if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		while (
			line.length() > 1
			and font.get_string_size(
				line + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
			).x > available
		):
			line = line.substr(0, line.length() - 1)
		line += "…"
	var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(
		font,
		Vector2(
			strip.position.x + maxf(1.0, (strip.size.x - width) * 0.5),
			strip.position.y + font.get_ascent(font_size) + 1.0
		),
		line,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)


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
			if _suppress_next_slot_click:
				_suppress_next_slot_click = false
				accept_event()
				return
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
	# Drop ends with a mouse-up on this control; skip the click that would stow.
	_suppress_next_slot_click = true
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
