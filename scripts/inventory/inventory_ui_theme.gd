class_name InventoryUiTheme
extends RefCounted

## Visual tokens for the bag overlay.
## Matches the minimap oak/brass HUD so the satchel reads as 14th-century Reval
## kit (leather pouch, brass fittings, parchment ink) without new texture assets.

const PANEL_BG := Color(0.085, 0.052, 0.028, 0.96)
const PANEL_BORDER := Color(0.42, 0.26, 0.12, 1.0)
const PANEL_SHADOW := Color(0.0, 0.0, 0.0, 0.55)
const BRASS := Color(0.72, 0.58, 0.31, 1.0)
const BRASS_BRIGHT := Color(0.93, 0.79, 0.48, 0.95)
const PARCHMENT := Color(0.96, 0.91, 0.81, 1.0)
const INK_MUTED := Color(0.78, 0.70, 0.58, 1.0)
const INK_BODY := Color(0.90, 0.84, 0.72, 1.0)
const LEATHER_EMPTY := Color(0.16, 0.11, 0.07, 0.96)
const LEATHER_VALID := Color(0.22, 0.28, 0.16, 0.96)
const DIM_SCRIM := Color(0.06, 0.04, 0.02, 0.74)
const SILHOUETTE_FILL := Color(0.34, 0.24, 0.16, 0.94)
const SILHOUETTE_STROKE := Color(0.18, 0.11, 0.06, 0.98)
const SLOT_EMPTY := Color(0.14, 0.09, 0.05, 0.88)
const SLOT_FILLED := Color(0.46, 0.34, 0.18, 0.94)
const METER_TRACK := Color(0.12, 0.08, 0.04, 0.95)
const METER_FILL := Color(0.62, 0.48, 0.24, 0.98)
const METER_FILL_HEAVY := Color(0.62, 0.30, 0.18, 0.98)

## Period dye / metal tones instead of neon UI hues.
const CATEGORY_COLORS := {
	"weapon": Color(0.62, 0.34, 0.22, 0.95), # madder / forge iron
	"evidence": Color(0.42, 0.48, 0.58, 0.95), # woad-stained cloth
	"commission_object": Color(0.72, 0.58, 0.28, 0.95), # brass
	"material": Color(0.38, 0.46, 0.30, 0.95), # oak gall / verdigris mix
	"supply": Color(0.40, 0.48, 0.42, 0.95), # linen green-gray
	"quest_tool": Color(0.52, 0.36, 0.48, 0.95), # berry dye
}


static func apply_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.set_corner_radius_all(8)
	style.shadow_color = PANEL_SHADOW
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)


static func apply_title(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", BRASS_BRIGHT)
	label.add_theme_color_override("font_shadow_color", Color(0.05, 0.03, 0.02, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)


static func apply_caption(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", INK_MUTED)


static func apply_body(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", INK_BODY)


static func apply_hint(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", INK_MUTED)


static func apply_meter_label(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", PARCHMENT)


static func apply_meter_value(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", INK_MUTED)


static func apply_action_button(button: Button) -> void:
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_hover_color", BRASS_BRIGHT)
	button.add_theme_color_override("font_pressed_color", BRASS)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.16, 0.10, 0.05, 0.96)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.22, 0.14, 0.07, 0.98)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.12, 0.08, 0.04, 0.98)))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.22, 0.14, 0.07, 0.98), true))


static func apply_progress_bar(bar: ProgressBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = METER_TRACK
	track.border_color = PANEL_BORDER
	track.set_border_width_all(1)
	track.set_corner_radius_all(4)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill := StyleBoxFlat.new()
	fill.bg_color = METER_FILL
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)


static func set_meter_fill_color(bar: ProgressBar, heavy: bool) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = METER_FILL_HEAVY if heavy else METER_FILL
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)


static func cell_style(bg: Color, focused: bool = false, selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = BRASS_BRIGHT if focused or selected else BRASS
	style.set_border_width_all(2 if focused or selected else 1)
	style.set_corner_radius_all(4)
	return style


static func apply_cell_button(button: Button, bg: Color, focused: bool, selected: bool) -> void:
	var style := cell_style(bg, focused, selected)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", cell_style(bg.lightened(0.08), true, selected))
	button.add_theme_stylebox_override("pressed", cell_style(bg.darkened(0.06), focused, selected))
	button.add_theme_stylebox_override("focus", cell_style(bg.lightened(0.06), true, selected))
	button.add_theme_color_override("font_color", PARCHMENT)
	button.modulate = Color.WHITE


static func make_brass_rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color(BRASS.r, BRASS.g, BRASS.b, 0.55)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


static func _button_style(bg: Color, bright_border: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = BRASS_BRIGHT if bright_border else BRASS
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
