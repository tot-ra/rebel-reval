extends RefCounted

## Shared charcoal/bronze UI skin; no external game artwork or new font assets.
## Escape menu and start screen (R-1698, R-1799) use make_theme(); the journal,
## inventory, spellforge and controls overlays use make_overlay_theme() and
## apply_overlay() (R-1800).
const GOLD := Color("b69a68")
const INK := Color("171b1c")
const TEXT := Color("e7ddc9")
const TEXT_BRIGHT := Color("fff0cb")
const TEXT_MUTED := Color("aa9980")
const TEXT_DISABLED := Color(0.55, 0.53, 0.49, 1.0)
const SCRIM := Color(0.02, 0.024, 0.024, 0.86)
const OVERLAY_FILL := Color(0.05, 0.06, 0.06, 0.94)
const SECTION_FILL := Color(0.08, 0.09, 0.09, 0.7)
const RULE := Color(0.58, 0.49, 0.33, 0.5)


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	for kind in ["Label", "Button", "OptionButton", "CheckButton"]:
		theme.set_color("font_color", kind, TEXT)
	for kind in ["Button", "OptionButton", "CheckButton"]:
		theme.set_stylebox("normal", kind, panel(SECTION_FILL))
		theme.set_stylebox("hover", kind, panel(Color("33322b")))
		theme.set_stylebox("pressed", kind, panel(Color("464034")))
		theme.set_stylebox("focus", kind, focus_style())
		theme.set_color("font_focus_color", kind, TEXT_BRIGHT)
		theme.set_color("font_hover_color", kind, TEXT_BRIGHT)
	theme.set_stylebox("focus", "HSlider", focus_style())
	return theme


## The Escape-menu theme plus the controls the overlays add (tabs, lists, rules).
## WHY 16 px: the overlays were laid out for Godot's default font size; the
## Escape menu's 18 px pushes the controls rows and spellforge buttons past 720p.
static func make_overlay_theme() -> Theme:
	var theme := make_theme()
	theme.default_font_size = 16
	var disabled := panel(Color(0.06, 0.065, 0.065, 0.55))
	disabled.border_color = Color(RULE, 0.2)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_color("font_disabled_color", "Button", TEXT_DISABLED)
	theme.set_stylebox("panel", "TabContainer", _flat(Color(0, 0, 0, 0), 0, 10))
	theme.set_stylebox("tab_selected", "TabContainer", _tab(Color("33322b"), GOLD, 2))
	theme.set_stylebox("tab_hovered", "TabContainer", _tab(Color("2a2925"), RULE, 1))
	theme.set_stylebox("tab_unselected", "TabContainer", _tab(SECTION_FILL, RULE, 1))
	theme.set_stylebox("tab_focus", "TabContainer", focus_style())
	theme.set_color("font_selected_color", "TabContainer", TEXT_BRIGHT)
	theme.set_color("font_hovered_color", "TabContainer", TEXT_BRIGHT)
	theme.set_color("font_unselected_color", "TabContainer", TEXT_MUTED)
	var list := panel(SECTION_FILL)
	list.content_margin_top = 6
	list.content_margin_bottom = 6
	theme.set_stylebox("panel", "ItemList", list)
	theme.set_stylebox("focus", "ItemList", focus_style())
	theme.set_stylebox("selected", "ItemList", _flat(Color("33322b"), 0, 0))
	theme.set_stylebox("selected_focus", "ItemList", _flat(Color("464034"), 0, 0))
	theme.set_stylebox("cursor", "ItemList", focus_style())
	theme.set_stylebox("cursor_unfocused", "ItemList", _flat(Color(0, 0, 0, 0), 0, 0))
	theme.set_color("font_color", "ItemList", TEXT)
	theme.set_color("font_selected_color", "ItemList", TEXT_BRIGHT)
	theme.set_color("font_hovered_color", "ItemList", TEXT_BRIGHT)
	var rule := StyleBoxLine.new()
	rule.color = RULE
	rule.thickness = 1
	theme.set_stylebox("separator", "HSeparator", rule)
	return theme


## Skins one full-screen overlay: theme on its root, the shared scrim, and the
## bronze-ruled charcoal panel. Call again from open() so a changed
## "enhanced focus" setting reaches the focus rings (UiFocusTheme is read at
## theme-build time).
static func apply_overlay(root: Control, overlay_panel: PanelContainer, dim: ColorRect) -> void:
	# open() may run before _ready() has built the nodes; _ready() skins them then.
	if root == null:
		return
	root.theme = make_overlay_theme()
	if dim != null:
		dim.color = SCRIM
	if overlay_panel != null:
		overlay_panel.add_theme_stylebox_override("panel", overlay_panel_style())


static func overlay_panel_style() -> StyleBoxFlat:
	var style := _flat(OVERLAY_FILL, 0, 0)
	style.border_color = Color(GOLD, 0.7)
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	return style


static func apply_title(label: Label, size: int = 28) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GOLD)


static func apply_muted(label: Label) -> void:
	label.add_theme_color_override("font_color", TEXT_MUTED)


static func focus_style() -> StyleBoxFlat:
	var focus := panel(Color(0, 0, 0, 0))
	UiFocusTheme.apply_button_focus_style(focus, GOLD)
	return focus


static func panel(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = RULE
	style.border_width_bottom = 1
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func _flat(color: Color, horizontal: int, vertical: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


static func _tab(color: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := _flat(color, 14, 6)
	style.border_color = border
	style.border_width_bottom = width
	return style
