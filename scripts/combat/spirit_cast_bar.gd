class_name SpiritCastBar
extends Control
## Compact cast bar of the real-time 3D arena (ADR 0038, SA3D-3), replacing the reply-card hotbar
## there: one small element-coloured tile per word-spell slot with its initial, its slot key, a
## dark cooldown sweep that unwinds clockwise, a gold rim on the slots whose word answers the
## opponent now, and a dimmed tile when the word cannot be cast (no willpower, duel over).
## Procedural `_draw` only, no texture assets (P0-040).

const TILE := 46.0
const GAP := 8.0
const ANSWER_RIM := Color(1.0, 0.82, 0.36)
const SWEEP_COLOR := Color(0.0, 0.0, 0.0, 0.62)
const SWEEP_SEGMENTS := 24

## Per slot: {element, key, cooldown (0..1), answers (bool), blocked (bool)}.
var slots: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func set_slots(next: Array[Dictionary]) -> void:
	slots = next
	custom_minimum_size = Vector2(maxf(0.0, slots.size() * (TILE + GAP) - GAP), TILE + 16.0)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for index in slots.size():
		var slot: Dictionary = slots[index]
		var rect := Rect2(Vector2(index * (TILE + GAP), 0.0), Vector2(TILE, TILE))
		var element := String(slot.get("element", ""))
		var color: Color = SpiritSpellCard.ELEMENT_COLORS.get(element, SpiritSpellCard.NEUTRAL_COLOR)
		if bool(slot.get("blocked", false)):
			color = color.darkened(0.55)
		draw_rect(rect, color)
		var initial := element.substr(0, 1).to_upper()
		draw_string(
			font, rect.position + Vector2(0.0, TILE * 0.66), initial, HORIZONTAL_ALIGNMENT_CENTER, TILE, 22
		)
		var cooldown := float(slot.get("cooldown", 0.0))
		if cooldown > 0.0:
			_draw_sweep(rect, cooldown)
		var rim := ANSWER_RIM if bool(slot.get("answers", false)) else Color(0.0, 0.0, 0.0, 0.7)
		draw_rect(rect, rim, false, 3.0 if bool(slot.get("answers", false)) else 1.0)
		draw_string(
			font,
			rect.position + Vector2(0.0, TILE + 14.0),
			String(slot.get("key", "")),
			HORIZONTAL_ALIGNMENT_CENTER,
			TILE,
			12
		)


## Dark pie over the remaining share of the cooldown, starting at twelve o'clock.
func _draw_sweep(rect: Rect2, fraction: float) -> void:
	var center := rect.get_center()
	var radius := rect.size.length() * 0.5
	var points := PackedVector2Array([center])
	var steps := maxi(2, ceili(SWEEP_SEGMENTS * fraction))
	for step in steps + 1:
		# The ready share unwinds from the top: the dark pie covers the angle still to go.
		var angle := -PI * 0.5 + TAU * (1.0 - fraction) + TAU * fraction * float(step) / float(steps)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	# Clip the pie to the tile so the corners show the sweep without spilling over.
	var clipped := Geometry2D.intersect_polygons(
		points,
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])  # gdlint: ignore=max-line-length
	)
	for polygon: PackedVector2Array in clipped:
		draw_colored_polygon(polygon, SWEEP_COLOR)
