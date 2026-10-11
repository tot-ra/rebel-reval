extends RefCounted

## Original charcoal/bronze UI skin; no external game artwork or new font assets.
const GOLD := Color("b69a68")
const INK := Color("171b1c")


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	for kind in ["Label", "Button", "OptionButton", "CheckButton"]:
		theme.set_color("font_color", kind, Color("e7ddc9"))
	for kind in ["Button", "OptionButton", "CheckButton"]:
		theme.set_stylebox("normal", kind, panel(Color(0.08, 0.09, 0.09, 0.7)))
		theme.set_stylebox("hover", kind, panel(Color("33322b")))
		theme.set_stylebox("pressed", kind, panel(Color("464034")))
		var focus := panel(Color(0, 0, 0, 0))
		UiFocusTheme.apply_button_focus_style(focus, GOLD)
		theme.set_stylebox("focus", kind, focus)
		theme.set_color("font_focus_color", kind, Color("fff0cb"))
		theme.set_color("font_hover_color", kind, Color("fff0cb"))
	var slider_focus := panel(Color(0, 0, 0, 0))
	UiFocusTheme.apply_button_focus_style(slider_focus, GOLD)
	theme.set_stylebox("focus", "HSlider", slider_focus)
	return theme


static func panel(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.58, 0.49, 0.33, 0.5)
	style.border_width_bottom = 1
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
