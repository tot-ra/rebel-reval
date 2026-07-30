class_name EquipmentSilhouette
extends Control

## Anatomical leather paper-doll with functional equipment drop zones.
## Slots stay data-driven: content may target any key in SLOT_ORDER while the
## existing hand/head/back records continue to behave exactly as before.

signal slot_pressed(slot: StringName)

const InventoryUiThemeScene := preload("res://scripts/inventory/inventory_ui_theme.gd")

const SLOT_ORDER: Array[StringName] = [
	&"head",
	&"back",
	&"body",
	&"arms",
	&"belt",
	&"legs",
	&"feet",
	&"left_hand",
	&"right_hand",
]

const SLOT_LABELS := {
	&"head": "Head",
	&"back": "Back",
	&"body": "Body",
	&"arms": "Arms",
	&"belt": "Belt",
	&"legs": "Legs",
	&"feet": "Feet",
	&"left_hand": "Left hand",
	&"right_hand": "Right hand",
}

const CAPTION_FONT_SIZE := 9
const DEFAULT_TOOLTIP := "Drag items onto slots. Click a worn slot to stow it in the bag."

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
	tooltip_text = DEFAULT_TOOLTIP
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

	# Four sockets on each flank leave an uninterrupted central figure. Belt is a
	# narrow central fitting because it belongs visually at the waist.
	var side := minf(w * 0.205, h * 0.175)
	var slot_size := Vector2(side, side)
	var left_x := w * 0.012
	var right_x := w - side - w * 0.012
	var top_y := h * 0.018
	var middle_y := h * 0.275
	var hand_y := h * 0.545
	var lower_y := h - side - h * 0.018
	var belt_size := Vector2(side * 1.18, side * 0.72)
	_slot_rects = {
		&"head": Rect2(Vector2(left_x, top_y), slot_size),
		&"back": Rect2(Vector2(right_x, top_y), slot_size),
		&"arms": Rect2(Vector2(left_x, middle_y), slot_size),
		&"body": Rect2(Vector2(right_x, middle_y), slot_size),
		&"left_hand": Rect2(Vector2(left_x, hand_y), slot_size),
		&"right_hand": Rect2(Vector2(right_x, hand_y), slot_size),
		&"legs": Rect2(Vector2(left_x, lower_y), slot_size),
		&"feet": Rect2(Vector2(right_x, lower_y), slot_size),
		&"belt": Rect2(Vector2((w - belt_size.x) * 0.5, h * 0.465), belt_size),
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
		var strip_height := float(ThemeDB.fallback_font.get_height(CAPTION_FONT_SIZE)) + 3.0
		icon_rect.position = rect.position + Vector2(4.0, 4.0)
		icon_rect.size = Vector2(rect.size.x - 8.0, rect.size.y - strip_height - 7.0)


func _draw() -> void:
	_draw_body_aura()
	_draw_body()
	_draw_slots()


func _draw_body_aura() -> void:
	var cx := size.x * 0.5
	var h := size.y
	# A faint arched niche separates the figure from the empty leather without
	# flattening it into another boxed widget.
	var niche := PackedVector2Array([
		Vector2(cx - size.x * 0.19, h * 0.90),
		Vector2(cx - size.x * 0.19, h * 0.20),
		Vector2(cx - size.x * 0.12, h * 0.09),
		Vector2(cx, h * 0.045),
		Vector2(cx + size.x * 0.12, h * 0.09),
		Vector2(cx + size.x * 0.19, h * 0.20),
		Vector2(cx + size.x * 0.19, h * 0.90),
	])
	draw_colored_polygon(niche, Color(InventoryUiThemeScene.SECTION_INSET, 0.34))
	draw_polyline(niche, Color(InventoryUiThemeScene.BRASS, 0.20), 1.0, true)


func _draw_body() -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var fill := InventoryUiThemeScene.SILHOUETTE_FILL
	var mid := InventoryUiThemeScene.SILHOUETTE_MID
	var highlight := InventoryUiThemeScene.SILHOUETTE_HIGHLIGHT
	var stroke := InventoryUiThemeScene.SILHOUETTE_STROKE
	var brass := InventoryUiThemeScene.BRASS

	# Head and neck use overlapping ellipses/polygons rather than one square cap.
	_draw_ellipse(Vector2(cx, h * 0.115), Vector2(w * 0.047, h * 0.070), Color(0, 0, 0, 0.30))
	_draw_ellipse(Vector2(cx - 1, h * 0.108), Vector2(w * 0.046, h * 0.068), fill)
	draw_arc(Vector2(cx - 1, h * 0.108), h * 0.067, -0.55, 1.45, 12, highlight, 1.1, true)
	var neck := PackedVector2Array([
		Vector2(cx - w * 0.025, h * 0.168),
		Vector2(cx + w * 0.025, h * 0.168),
		Vector2(cx + w * 0.032, h * 0.210),
		Vector2(cx - w * 0.032, h * 0.210),
	])
	_fill_shape(neck, mid, stroke, 1.2)

	# Broad shoulders taper naturally through chest, waist and hips.
	var torso := PackedVector2Array([
		Vector2(cx - w * 0.125, h * 0.215),
		Vector2(cx - w * 0.155, h * 0.255),
		Vector2(cx - w * 0.118, h * 0.445),
		Vector2(cx - w * 0.098, h * 0.535),
		Vector2(cx, h * 0.558),
		Vector2(cx + w * 0.098, h * 0.535),
		Vector2(cx + w * 0.118, h * 0.445),
		Vector2(cx + w * 0.155, h * 0.255),
		Vector2(cx + w * 0.125, h * 0.215),
		Vector2(cx + w * 0.040, h * 0.190),
		Vector2(cx - w * 0.040, h * 0.190),
	])
	_fill_shape(_offset_points(torso, Vector2(2, 3)), Color(0, 0, 0, 0.28), Color.TRANSPARENT, 0.0)
	_fill_shape(torso, fill, stroke, 1.7)

	# Collar, chest seam and belt make the body legible as clothed Kalev rather
	# than a nude diagram, while preserving the anatomy underneath.
	var collar := PackedVector2Array([
		Vector2(cx - w * 0.055, h * 0.205),
		Vector2(cx, h * 0.255),
		Vector2(cx + w * 0.055, h * 0.205),
	])
	draw_polyline(collar, Color(brass, 0.52), 1.2, true)
	draw_line(Vector2(cx, h * 0.255), Vector2(cx, h * 0.445), Color(stroke, 0.60), 1.0)
	draw_line(Vector2(cx - w * 0.105, h * 0.455), Vector2(cx + w * 0.105, h * 0.455), mid, h * 0.022)
	draw_rect(Rect2(cx - w * 0.018, h * 0.442, w * 0.036, h * 0.026), brass, false, 1.4)

	# Bent arms: upper arm, elbow and forearm each have different angles and widths.
	_draw_limb([
		Vector2(cx - w * 0.137, h * 0.245), Vector2(cx - w * 0.175, h * 0.430),
		Vector2(cx - w * 0.145, h * 0.610)
	], [w * 0.032, w * 0.027, w * 0.021], mid, stroke)
	_draw_limb([
		Vector2(cx + w * 0.137, h * 0.245), Vector2(cx + w * 0.175, h * 0.430),
		Vector2(cx + w * 0.145, h * 0.610)
	], [w * 0.032, w * 0.027, w * 0.021], mid, stroke)
	_draw_ellipse(Vector2(cx - w * 0.145, h * 0.625), Vector2(w * 0.024, h * 0.035), fill)
	_draw_ellipse(Vector2(cx + w * 0.145, h * 0.625), Vector2(w * 0.024, h * 0.035), fill)

	# Separate thighs, knees, calves and outward feet sell a grounded human stance.
	_draw_limb([
		Vector2(cx - w * 0.055, h * 0.545), Vector2(cx - w * 0.070, h * 0.715),
		Vector2(cx - w * 0.078, h * 0.875)
	], [w * 0.050, w * 0.044, w * 0.032], fill, stroke)
	_draw_limb([
		Vector2(cx + w * 0.055, h * 0.545), Vector2(cx + w * 0.070, h * 0.715),
		Vector2(cx + w * 0.078, h * 0.875)
	], [w * 0.050, w * 0.044, w * 0.032], fill, stroke)
	var left_foot := PackedVector2Array([
		Vector2(cx - w * 0.110, h * 0.875), Vector2(cx - w * 0.045, h * 0.875),
		Vector2(cx - w * 0.038, h * 0.915), Vector2(cx - w * 0.135, h * 0.915),
	])
	var right_foot := PackedVector2Array([
		Vector2(cx + w * 0.045, h * 0.875), Vector2(cx + w * 0.110, h * 0.875),
		Vector2(cx + w * 0.135, h * 0.915), Vector2(cx + w * 0.038, h * 0.915),
	])
	_fill_shape(left_foot, mid.darkened(0.18), stroke, 1.2)
	_fill_shape(right_foot, mid.darkened(0.18), stroke, 1.2)

	# Subtle highlights keep the figure dimensional against the dark leather.
	draw_line(Vector2(cx - w * 0.085, h * 0.275), Vector2(cx - w * 0.070, h * 0.410), Color(highlight, 0.34), 1.3)
	draw_line(Vector2(cx - w * 0.090, h * 0.590), Vector2(cx - w * 0.095, h * 0.825), Color(highlight, 0.25), 1.1)


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

		var border := InventoryUiThemeScene.BRASS
		if slot == _hover_slot or highlighted:
			border = InventoryUiThemeScene.BRASS_BRIGHT
		_draw_slot_frame(rect, base, border, highlighted)
		if not occupied:
			_draw_slot_glyph(slot, rect, Color(border, 0.24))

		var slot_name := String(SLOT_LABELS.get(slot, slot))
		var label := slot_name
		if occupied and _item_short_label.is_valid():
			label = String(_item_short_label.call(_equipped[slot]))
		elif occupied and _item_label.is_valid():
			label = String(_item_label.call(_equipped[slot]))
		_draw_slot_caption(rect, label, occupied)


func _draw_slot_frame(rect: Rect2, base: Color, border: Color, highlighted: bool) -> void:
	var cut := minf(7.0, minf(rect.size.x, rect.size.y) * 0.14)
	var points := _chamfered_rect_points(rect, cut)
	var shadow := _offset_points(points, Vector2(2, 3))
	_fill_shape(shadow, Color(0, 0, 0, 0.32), Color.TRANSPARENT, 0.0)
	_fill_shape(points, base, border, 2.2 if highlighted else 1.35)
	var inset := rect.grow(-3.0)
	draw_polyline(_closed_points(_chamfered_rect_points(inset, maxf(2.0, cut - 2.0))), Color(border, 0.30), 0.8, true)
	for rivet in [
		Vector2(rect.position.x + cut + 1.0, rect.position.y + 3.0),
		Vector2(rect.end.x - cut - 1.0, rect.position.y + 3.0),
	]:
		draw_circle(rivet, 1.15, Color(border, 0.80))


func _draw_slot_glyph(slot: StringName, rect: Rect2, color: Color) -> void:
	var center := rect.get_center() - Vector2(0, 5)
	var radius := minf(rect.size.x, rect.size.y) * 0.18
	match slot:
		&"head":
			draw_arc(center, radius, PI, TAU, 16, color, 2.0, true)
			draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), color, 2.0)
		&"back":
			var shield := PackedVector2Array([
				center + Vector2(-radius, -radius), center + Vector2(radius, -radius),
				center + Vector2(radius * 0.8, radius * 0.65), center + Vector2(0, radius * 1.25),
				center + Vector2(-radius * 0.8, radius * 0.65),
			])
			draw_polyline(_closed_points(shield), color, 1.7, true)
		&"body":
			var tunic := PackedVector2Array([
				center + Vector2(-radius * 1.3, -radius), center + Vector2(-radius * 0.5, -radius * 1.35),
				center + Vector2(radius * 0.5, -radius * 1.35), center + Vector2(radius * 1.3, -radius),
				center + Vector2(radius * 0.75, radius * 1.25), center + Vector2(-radius * 0.75, radius * 1.25),
			])
			draw_polyline(_closed_points(tunic), color, 1.7, true)
		&"arms":
			draw_line(center + Vector2(-radius, -radius), center + Vector2(-radius * 0.2, radius), color, 3.0)
			draw_line(center + Vector2(radius, -radius), center + Vector2(radius * 0.2, radius), color, 3.0)
		&"belt":
			draw_line(center + Vector2(-radius * 1.8, 0), center + Vector2(radius * 1.8, 0), color, 3.0)
			draw_rect(Rect2(center - Vector2(radius * 0.35, radius * 0.30), Vector2(radius * 0.70, radius * 0.60)), color, false, 1.5)
		&"legs":
			draw_line(center + Vector2(-radius * 0.55, -radius), center + Vector2(-radius * 0.75, radius), color, 3.0)
			draw_line(center + Vector2(radius * 0.55, -radius), center + Vector2(radius * 0.75, radius), color, 3.0)
		&"feet":
			draw_line(center + Vector2(-radius, -radius * 0.5), center + Vector2(-radius * 1.25, radius * 0.6), color, 3.0)
			draw_line(center + Vector2(radius * 0.3, -radius * 0.5), center + Vector2(radius * 1.25, radius * 0.6), color, 3.0)
		&"left_hand", &"right_hand":
			draw_circle(center, radius * 0.55, color, false, 1.7, true)
			draw_line(center + Vector2(0, -radius * 1.25), center + Vector2(0, radius * 1.25), color, 1.7)


func _icon_for(item_id: StringName) -> Texture2D:
	if not _item_icon.is_valid():
		return null
	var icon: Variant = _item_icon.call(item_id)
	return icon as Texture2D


func _draw_slot_caption(rect: Rect2, text: String, occupied: bool) -> void:
	var font := ThemeDB.fallback_font
	var font_size := CAPTION_FONT_SIZE
	var strip_height := float(font.get_height(font_size)) + 3.0
	var strip := Rect2(
		Vector2(rect.position.x + 1.0, rect.end.y - strip_height - 1.0),
		Vector2(rect.size.x - 2.0, strip_height)
	)
	draw_rect(strip, Color(0.035, 0.018, 0.008, 0.84 if occupied else 0.58))
	var color := InventoryUiThemeScene.PARCHMENT if occupied else InventoryUiThemeScene.INK_MUTED
	var available := strip.size.x - 4.0
	var line := text
	while font_size > CAPTION_FONT_SIZE - 2:
		if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= available:
			break
		font_size -= 1
	if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		while (
			line.length() > 1
			and font.get_string_size(line + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available
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
			tooltip_text = DEFAULT_TOOLTIP
			queue_redraw()


func _update_hover_tooltip(slot: StringName) -> void:
	if slot.is_empty():
		tooltip_text = DEFAULT_TOOLTIP
		return
	var slot_name := String(SLOT_LABELS.get(slot, slot))
	if _equipped.has(slot) and not String(_equipped[slot]).is_empty() and _item_label.is_valid():
		tooltip_text = "%s: %s\nClick to stow in the bag." % [
			slot_name,
			String(_item_label.call(_equipped[slot])),
		]
		return
	tooltip_text = "%s slot\nDrop a matching item here." % slot_name


func _draw_limb(
	centers: Array[Vector2],
	radii: Array[float],
	fill: Color,
	stroke: Color
) -> void:
	if centers.size() != 3 or radii.size() != 3:
		return
	for index in range(2):
		var from := centers[index]
		var to := centers[index + 1]
		var direction := (to - from).normalized()
		var normal := Vector2(-direction.y, direction.x)
		var segment := PackedVector2Array([
			from + normal * radii[index],
			to + normal * radii[index + 1],
			to - normal * radii[index + 1],
			from - normal * radii[index],
		])
		_fill_shape(segment, fill, stroke, 1.2)
		draw_circle(centers[index + 1], radii[index + 1], fill)
		draw_arc(centers[index + 1], radii[index + 1], 0, TAU, 14, stroke, 1.0, true)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(28):
		var angle := TAU * float(index) / 28.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)


func _fill_shape(points: PackedVector2Array, fill: Color, stroke: Color, width: float) -> void:
	if points.size() < 3:
		return
	draw_colored_polygon(points, fill)
	if stroke.a > 0.0 and width > 0.0:
		draw_polyline(_closed_points(points), stroke, width, true)


func _chamfered_rect_points(rect: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(rect.position.x + cut, rect.position.y),
		Vector2(rect.end.x - cut, rect.position.y),
		Vector2(rect.end.x, rect.position.y + cut),
		Vector2(rect.end.x, rect.end.y - cut),
		Vector2(rect.end.x - cut, rect.end.y),
		Vector2(rect.position.x + cut, rect.end.y),
		Vector2(rect.position.x, rect.end.y - cut),
		Vector2(rect.position.x, rect.position.y + cut),
	])


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if not points.is_empty():
		closed.append(points[0])
	return closed


func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	for point in points:
		shifted.append(point + offset)
	return shifted
