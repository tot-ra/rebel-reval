class_name SpiritCastBar
extends Control
## Compact cast bar of the real-time 3D arena (ADR 0038, SA3D-3), replacing the reply-card hotbar
## there: one small element-coloured tile per word-spell slot with its initial, its slot key, a
## dark cooldown sweep that unwinds clockwise, a gold rim on the slots whose word answers the
## opponent now, a dimmed tile when the word cannot be cast (no willpower, duel over), and a
## "weak" tag over a word aimed at a closed or ember soul light of the opponent (R-1764).
## R-1872: each tile shows the word's painted sigil (assets/UI/spirit_words, provenance in
## assets/SOURCES.csv) framed in the element colour, with the word's name and slot key below;
## an element without a sigil falls back to its coloured tile and initial.
## ADR 0048 (SPL-2): a small arrow in the tile's top-right corner says which way the slot's spell
## moves the light it reaches: down (lowering, pressure), up (raising, trust) or both (mixed).

const TILE := 56.0
const GAP := 10.0
## Word element -> painted sigil. Fear red eye-flame, shame blue bowed head, duty gold key and
## scale, love green cupped hands, faith violet candle over a cross.
const ICONS: Dictionary = {
	"fear": preload("res://assets/UI/spirit_words/word_fear.png"),
	"shame": preload("res://assets/UI/spirit_words/word_shame.png"),
	"duty": preload("res://assets/UI/spirit_words/word_duty.png"),
	"love": preload("res://assets/UI/spirit_words/word_love.png"),
	"faith": preload("res://assets/UI/spirit_words/word_faith.png"),
}
const FRAME_WIDTH := 2.0
const NAME_COLOR := Color(0.93, 0.88, 0.78)
const ANSWER_RIM := Color(1.0, 0.82, 0.36)
const SWEEP_COLOR := Color(0.0, 0.0, 0.0, 0.62)
const SWEEP_SEGMENTS := 24
const WEAK_COLOR := Color(1.0, 0.95, 0.75)
const ARROW_SIZE := 9.0
const RAISE_COLOR := Color(0.55, 0.92, 0.60)
const LOWER_COLOR := Color(0.98, 0.50, 0.42)

## Per slot: {element, key, cooldown (0..1), answers (bool), blocked (bool), weak (bool),
## direction ("lowering" / "raising" / "mixed"; absent draws no arrow)}.
var slots: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func set_slots(next: Array[Dictionary]) -> void:
	slots = next
	custom_minimum_size = Vector2(maxf(0.0, slots.size() * (TILE + GAP) - GAP), TILE + 30.0)
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
		var icon: Texture2D = ICONS.get(element)
		if icon != null:
			# A blocked word (no willpower, duel over) dims its sigil instead of its tile colour.
			var tint := Color(0.4, 0.4, 0.45) if bool(slot.get("blocked", false)) else Color.WHITE
			draw_texture_rect(icon, rect, false, tint)
			draw_rect(rect, color, false, FRAME_WIDTH)
		else:
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
		_draw_direction(rect, String(slot.get("direction", "")))
		if bool(slot.get("weak", false)):
			draw_string(font, rect.position + Vector2(0.0, -4.0), "weak", HORIZONTAL_ALIGNMENT_CENTER, TILE, 12, WEAK_COLOR)  # gdlint: ignore=max-line-length
		draw_string(
			font, rect.position + Vector2(-GAP * 0.5, TILE + 14.0), element.capitalize(),
			HORIZONTAL_ALIGNMENT_CENTER, TILE + GAP, 12, NAME_COLOR
		)
		draw_string(
			font,
			rect.position + Vector2(0.0, TILE + 28.0),
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


## Raise / lower arrows in the tile's top-right corner (mixed shows both, side by side).
func _draw_direction(rect: Rect2, direction: String) -> void:
	var corner := Vector2(rect.end.x - ARROW_SIZE - 3.0, rect.position.y + 3.0)
	match direction:
		"lowering":
			_draw_arrow(corner, false)
		"raising":
			_draw_arrow(corner, true)
		"mixed":
			_draw_arrow(corner, true)
			_draw_arrow(corner - Vector2(ARROW_SIZE + 2.0, 0.0), false)


func _draw_arrow(at: Vector2, up: bool) -> void:
	var w := ARROW_SIZE
	var points := (
		PackedVector2Array([at + Vector2(w * 0.5, 0.0), at + Vector2(w, w), at + Vector2(0.0, w)])
		if up
		else PackedVector2Array([at, at + Vector2(w, 0.0), at + Vector2(w * 0.5, w)])
	)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_colored_polygon(points, RAISE_COLOR if up else LOWER_COLOR)
	draw_polyline(outline, Color(0.0, 0.0, 0.0, 0.8), 1.0)
