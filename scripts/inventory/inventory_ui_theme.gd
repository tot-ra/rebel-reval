class_name InventoryUiTheme
extends RefCounted

const UiFocusThemeScript := preload("res://scripts/ui/ui_focus_theme.gd")
## Matches the minimap oak/brass HUD so the satchel reads as 14th-century Reval
## kit (leather pouch, brass fittings, parchment ink) without new texture assets.

const PANEL_BG := Color(0.052, 0.030, 0.017, 0.985)
const PANEL_BORDER := Color(0.46, 0.29, 0.12, 1.0)
const PANEL_SHADOW := Color(0.0, 0.0, 0.0, 0.72)
const SECTION_BG := Color(0.035, 0.021, 0.012, 0.76)
const SECTION_INSET := Color(0.12, 0.075, 0.035, 0.72)
const BRASS_DARK := Color(0.34, 0.22, 0.10, 1.0)
const BRASS := Color(0.72, 0.55, 0.25, 1.0)
const BRASS_BRIGHT := Color(0.96, 0.78, 0.40, 0.98)
const PARCHMENT := Color(0.96, 0.91, 0.81, 1.0)
const INK_MUTED := Color(0.76, 0.68, 0.55, 1.0)
const INK_BODY := Color(0.90, 0.84, 0.72, 1.0)
const LEATHER_EMPTY := Color(0.125, 0.078, 0.043, 0.98)
const LEATHER_VALID := Color(0.20, 0.27, 0.14, 0.98)
const DIM_SCRIM := Color(0.025, 0.015, 0.008, 0.82)
const SILHOUETTE_FILL := Color(0.31, 0.205, 0.125, 0.98)
const SILHOUETTE_MID := Color(0.225, 0.14, 0.085, 0.98)
const SILHOUETTE_HIGHLIGHT := Color(0.43, 0.30, 0.18, 0.92)
const SILHOUETTE_STROKE := Color(0.105, 0.060, 0.028, 1.0)
const SLOT_EMPTY := Color(0.105, 0.061, 0.031, 0.95)
const SLOT_FILLED := Color(0.43, 0.30, 0.14, 0.96)
const METER_TRACK := Color(0.09, 0.05, 0.025, 0.98)
const METER_FILL := Color(0.64, 0.45, 0.18, 0.98)
const METER_FILL_HEAVY := Color(0.64, 0.25, 0.13, 0.98)

## Period dye / metal tones instead of neon UI hues.
const CATEGORY_COLORS := {
	"weapon": Color(0.62, 0.34, 0.22, 0.95),  # madder / forge iron
	"evidence": Color(0.42, 0.48, 0.58, 0.95),  # woad-stained cloth
	"commission_object": Color(0.72, 0.58, 0.28, 0.95),  # brass
	"material": Color(0.38, 0.46, 0.30, 0.95),  # oak gall / verdigris mix
	"supply": Color(0.40, 0.48, 0.42, 0.95),  # linen green-gray
	"quest_tool": Color(0.52, 0.36, 0.48, 0.95),  # berry dye
}


static func apply_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(3)
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.set_corner_radius_all(4)
	style.corner_radius_top_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = PANEL_SHADOW
	style.shadow_size = 24
	style.shadow_offset = Vector2(0, 9)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)


## Framed sub-section (worn gear, packed goods, load, inspected item).
## WHY: grouping the columns in their own leather frames stops the overlay from
## reading as one flat wall of widgets.
static func apply_section_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = SECTION_BG
	style.border_color = Color(BRASS.r, BRASS.g, BRASS.b, 0.66)
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.set_corner_radius_all(3)
	style.corner_radius_top_left = 9
	style.corner_radius_bottom_right = 9
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)


## Warm hearth glow behind the satchel contents, drawn as a radial gradient so no
## extra texture asset is needed.
static func make_panel_glow() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.40, 0.26, 0.12, 0.30))
	gradient.set_color(1, Color(0.03, 0.02, 0.01, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.32)
	texture.fill_to = Vector2(1.05, 1.0)
	texture.width = 256
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


static func apply_title(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", BRASS_BRIGHT)
	label.add_theme_color_override("font_outline_color", Color(BRASS_DARK, 0.92))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.005, 0.98))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 3)


static func apply_subtitle(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(INK_MUTED.r, INK_MUTED.g, INK_MUTED.b, 0.85))


static func apply_section_caption(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", BRASS_BRIGHT)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("letter_spacing", 1)


static func apply_detail_title(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", BRASS_BRIGHT)


## Stack count drawn in the cell corner instead of squeezed into the item label.
static func apply_quantity_badge(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", PARCHMENT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.045, 0.02, 0.92)
	style.border_color = Color(BRASS.r, BRASS.g, BRASS.b, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	label.add_theme_stylebox_override("normal", style)


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


static func cell_style(
	bg: Color, focused: bool = false, selected: bool = false, accent: Color = Color(0, 0, 0, 0)
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	# WHY: the category tint used to flood the cell and drown the painted icon;
	# it now rides the border so the artwork stays legible.
	var border := BRASS
	if accent.a > 0.0:
		border = accent.lightened(0.12)
	if selected:
		border = BRASS_BRIGHT
	elif focused:
		border = BRASS_BRIGHT.lerp(border, 0.35)
	style.border_color = UiFocusThemeScript.focus_border_color(border) if focused else border
	style.set_border_width_all(
		UiFocusThemeScript.focus_border_width() if focused else (2 if selected else 1)
	)
	style.set_corner_radius_all(3)
	style.corner_radius_top_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	if selected:
		style.shadow_color = Color(BRASS_BRIGHT.r, BRASS_BRIGHT.g, BRASS_BRIGHT.b, 0.35)
		style.shadow_size = 6
	return style


static func apply_cell_button(
	button: Button, bg: Color, focused: bool, selected: bool, accent: Color = Color(0, 0, 0, 0)
) -> void:
	var style := cell_style(bg, focused, selected, accent)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override(
		"hover", cell_style(bg.lightened(0.10), true, selected, accent)
	)
	button.add_theme_stylebox_override(
		"pressed", cell_style(bg.darkened(0.06), focused, selected, accent)
	)
	button.add_theme_stylebox_override(
		"focus", cell_style(bg.lightened(0.06), true, selected, accent)
	)
	button.add_theme_color_override("font_color", PARCHMENT)
	button.modulate = Color.WHITE


## Brass divider that fades at both ends, like a hammered fitting rather than a
## hard UI line.
static func make_brass_rule() -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray(
		[
			Color(BRASS.r, BRASS.g, BRASS.b, 0.0),
			Color(BRASS_BRIGHT.r, BRASS_BRIGHT.g, BRASS_BRIGHT.b, 0.75),
			Color(BRASS.r, BRASS.g, BRASS.b, 0.0),
		]
	)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 1
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 0)
	var rule := TextureRect.new()
	rule.texture = texture
	rule.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rule.stretch_mode = TextureRect.STRETCH_SCALE
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


static func _button_style(bg: Color, bright_border: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	var border := BRASS_BRIGHT if bright_border else BRASS
	if bright_border:
		UiFocusThemeScript.apply_button_focus_style(style, border)
	else:
		style.border_color = border
		style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
