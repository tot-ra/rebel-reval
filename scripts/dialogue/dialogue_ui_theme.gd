class_name DialogueUiTheme
extends RefCounted

## Color tokens and panel styling for DialogueUI.

const COLOR_BODY_DEFAULT := Color(0.95, 0.95, 0.9, 1.0)
const COLOR_BODY_HIGH_CONTRAST := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_SPEAKER_DEFAULT := Color(0.92, 0.78, 0.42, 1.0)
const COLOR_SPEAKER_HIGH_CONTRAST := Color(1.0, 0.92, 0.35, 1.0)
const COLOR_HINT_DEFAULT := Color(0.72, 0.76, 0.82, 1.0)
const COLOR_HINT_HIGH_CONTRAST := Color(0.9, 0.93, 0.98, 1.0)
const COLOR_DISABLED_DEFAULT := Color(0.86, 0.55, 0.48, 1.0)
const COLOR_DISABLED_HIGH_CONTRAST := Color(1.0, 0.72, 0.62, 1.0)
const COLOR_PANEL_DEFAULT := Color(0.08, 0.09, 0.11, 0.88)
const COLOR_PANEL_HIGH_CONTRAST := Color(0.0, 0.0, 0.0, 0.96)
const COLOR_SUBTITLE_BACKGROUND := Color(0.0, 0.0, 0.0, 0.72)


static func apply_visual_theme(ui: DialogueUI) -> void:
	var settings = ui.get_settings()
	var body_color := COLOR_BODY_HIGH_CONTRAST if settings.high_contrast else COLOR_BODY_DEFAULT
	var speaker_color := COLOR_SPEAKER_HIGH_CONTRAST if settings.high_contrast else COLOR_SPEAKER_DEFAULT
	var hint_color := COLOR_HINT_HIGH_CONTRAST if settings.high_contrast else COLOR_HINT_DEFAULT
	var disabled_color := COLOR_DISABLED_HIGH_CONTRAST if settings.high_contrast else COLOR_DISABLED_DEFAULT
	var panel_color := COLOR_PANEL_HIGH_CONTRAST if settings.high_contrast else COLOR_PANEL_DEFAULT

	ui._speaker_label.add_theme_color_override("font_color", speaker_color)
	ui._text_label.add_theme_color_override("font_color", body_color)
	ui._continue_hint.add_theme_color_override("font_color", hint_color)
	ui._disabled_reason_label.add_theme_color_override("font_color", disabled_color)
	ui._portrait_fallback.add_theme_color_override("font_color", speaker_color)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = panel_color
	panel_style.set_corner_radius_all(6)
	ui._panel.add_theme_stylebox_override("panel", panel_style)
	ui._backlog_panel.add_theme_stylebox_override("panel", panel_style.duplicate())

	ui._text_background.visible = settings.subtitle_background
	if settings.subtitle_background:
		ui._text_background.color = COLOR_SUBTITLE_BACKGROUND if not settings.high_contrast else Color(0.0, 0.0, 0.0, 0.88)
