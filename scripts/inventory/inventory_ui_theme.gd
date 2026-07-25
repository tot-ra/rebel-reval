class_name InventoryUiTheme
extends RefCounted

## Visual tokens for the bag overlay.
## Matches the minimap oak/brass HUD so the satchel reads as 14th-century Reval
## kit (leather pouch, brass fittings, parchment ink) without new texture assets.

const PANEL_BG := Color(0.085, 0.052, 0.028, 0.96)
const PANEL_BORDER := Color(0.42, 0.26, 0.12, 1.0)
const PANEL_SHADOW := Color(0.0, 0.0, 0.0, 0.55)
const SECTION_BG := Color(0.055, 0.034, 0.018, 0.62)
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
	style.set_corner_radius_all(12)
	style.shadow_color = PANEL_SHADOW
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)


## Framed sub-section (worn gear, packed goods, load, inspected item).
## WHY: grouping the columns in their own leather frames stops the overlay from
## reading as one flat wall of widgets.
static func apply_section_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = SECTION_BG
	style.border_color = Color(BRASS.r, BRASS.g, BRASS.b, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
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
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", BRASS_BRIGHT)
	label.add_theme_color_override("font_shadow_color", Color(0.05, 0.03, 0.02, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)


static func apply_subtitle(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(INK_MUTED.r, INK_MUTED.g, INK_MUTED.b, 0.85))


static func apply_section_caption(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", BRASS)


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
	bg: Color,
	focused: bool = false,
	selected: bool = false,
	accent: Color = Color(0, 0, 0, 0)
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
	style.border_color = border
	style.set_border_width_all(2 if focused or selected else 1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	if selected:
		style.shadow_color = Color(BRASS_BRIGHT.r, BRASS_BRIGHT.g, BRASS_BRIGHT.b, 0.35)
		style.shadow_size = 6
	return style


static func apply_cell_button(
	button: Button,
	bg: Color,
	focused: bool,
	selected: bool,
	accent: Color = Color(0, 0, 0, 0)
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
	gradient.colors = PackedColorArray([
		Color(BRASS.r, BRASS.g, BRASS.b, 0.0),
		Color(BRASS_BRIGHT.r, BRASS_BRIGHT.g, BRASS_BRIGHT.b, 0.75),
		Color(BRASS.r, BRASS.g, BRASS.b, 0.0),
	])
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
	style.border_color = BRASS_BRIGHT if bright_border else BRASS
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
