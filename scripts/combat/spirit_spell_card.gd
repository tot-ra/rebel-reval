class_name SpiritSpellCard
extends Button
## One reply on the spirit arena hotbar (SD-18): slot key, an element-coloured icon placeholder,
## the spell name and willpower cost, and the spoken line as a caption. A card that cannot be
## picked is disabled and says why. Mouse click, focus + ui_accept (gamepad A) and the slot
## key (handled by SpiritArenaHost) all pick it.

const CARD_SIZE := Vector2(200.0, 150.0)
## Duel move elements (common.schema.json duel_move.element) -> card colour.
const ELEMENT_COLORS: Dictionary = {
	"fear": Color(0.56, 0.44, 0.82),
	"shame": Color(0.86, 0.36, 0.30),
	"duty": Color(0.40, 0.60, 0.86),
	"love": Color(0.90, 0.50, 0.66),
	"faith": Color(0.95, 0.84, 0.46),
	"coin": Color(0.80, 0.64, 0.30),
}
const NEUTRAL_COLOR := Color(0.58, 0.58, 0.62)

var choice_id := ""
var spell_id := ""
## The spoken line that voices the cast.
var caption := ""
## Why the card cannot be picked now; empty when it can.
var block_reason := ""
var voice_path := ""
var element_color := NEUTRAL_COLOR
## Full binding text ("1 / Gamepad X"); the card badge only has room for the keyboard key,
## so the gamepad button lives in the tooltip.
var binding_hint := ""

var _reason_label: Label


## `title` is the spell name (or the plain reply for a non-spell choice), `cost_text` e.g.
## "2 willpower" (empty for no cost), `key_text` the bound slot key ("1 / X").
func setup(
	choice: Dictionary, title: String, cost_text: String, key_text: String, reason: String
) -> void:
	choice_id = String(choice.get("id", ""))
	spell_id = String(choice.get("spell_id", ""))
	voice_path = String(choice.get("voice_path", ""))
	caption = String(choice.get("text", "")) if not spell_id.is_empty() else ""
	var move: Dictionary = choice.get("move", {})
	var element := String(move.get("element", ""))
	element_color = ELEMENT_COLORS.get(element, NEUTRAL_COLOR)
	custom_minimum_size = CARD_SIZE
	focus_mode = Control.FOCUS_ALL
	clip_text = true
	_build(title, cost_text, key_text, element, String(move.get("kind", "")))
	set_block_reason(reason)


func set_block_reason(reason: String) -> void:
	block_reason = reason
	disabled = not reason.is_empty()
	tooltip_text = reason if not reason.is_empty() else binding_hint
	_reason_label.text = reason
	_reason_label.visible = not reason.is_empty()
	modulate = Color(1, 1, 1, 0.55) if disabled else Color.WHITE


func _build(
	title: String, cost_text: String, key_text: String, element: String, kind: String
) -> void:
	for state_name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state_name, _card_style(state_name))
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 10.0
	column.offset_right = -10.0
	column.offset_top = 8.0
	column.offset_bottom = -8.0
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	# Icon placeholder: an element-coloured tile with the element initial until spell art exists.
	var icon_tile := ColorRect.new()
	icon_tile.color = element_color
	icon_tile.custom_minimum_size = Vector2(34.0, 34.0)
	icon_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(icon_tile)
	var glyph := _label(element.substr(0, 1).to_upper() if not element.is_empty() else "-", 20)
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_color_override("font_color", Color(0.08, 0.06, 0.10))
	icon_tile.add_child(glyph)
	# The name wraps over two lines instead of clipping: a plain reply ("[Shove him away]")
	# is as long as the card and used to be cut down to a couple of characters.
	var name_label := _label(title, 17)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	header.add_child(name_label)
	var key_label := _label(key_text, 14)
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	key_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70))
	header.add_child(key_label)
	var meta := cost_text
	if not kind.is_empty():
		meta = ("%s  |  %s %s" % [cost_text, kind, element]) if not cost_text.is_empty() else (
			"%s %s" % [kind, element]
		)
	var meta_label := _label(meta, 13)
	meta_label.add_theme_color_override("font_color", element_color.lightened(0.25))
	column.add_child(meta_label)
	if not caption.is_empty():
		var caption_label := _label("\"%s\"" % caption, 13)
		caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		caption_label.add_theme_color_override("font_color", Color(0.85, 0.84, 0.80))
		column.add_child(caption_label)
	_reason_label = _label("", 13)
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	column.add_child(_reason_label)


func _card_style(state_name: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.14, 0.92)
	style.set_corner_radius_all(6)
	style.set_border_width_all(2)
	style.border_color = element_color.darkened(0.35)
	match state_name:
		"hover":
			style.bg_color = Color(0.16, 0.13, 0.22, 0.95)
			style.border_color = element_color
		"pressed":
			style.bg_color = element_color.darkened(0.55)
			style.border_color = element_color.lightened(0.3)
		"focus":
			style.draw_center = false
			style.set_border_width_all(3)
			UiFocusTheme.apply_button_focus_style(style, element_color.lightened(0.4))
			style.set_border_width_all(maxi(3, UiFocusTheme.focus_border_width()))
		"disabled":
			style.bg_color = Color(0.07, 0.06, 0.08, 0.9)
			style.border_color = Color(0.30, 0.28, 0.32)
	return style


func _label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
