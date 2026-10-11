class_name UiFocusTheme
extends RefCounted

## Shared focus-ring styling driven by gameplay accessibility settings (P3-007).

const GameplaySettingsScript := preload("res://scripts/settings/gameplay_accessibility_settings.gd")

const DEFAULT_BORDER_WIDTH := 1
const ENHANCED_BORDER_WIDTH := 4


static func enhanced_focus_enabled() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("/root/UserSettings"):
		return false
	var settings: Node = tree.root.get_node("/root/UserSettings")
	if not ("gameplay" in settings):
		return false
	var gameplay: Variant = settings.get("gameplay")
	if gameplay == null or not gameplay.has_method("normalize"):
		return false
	return bool(gameplay.enhanced_focus_contrast)


static func focus_border_width() -> int:
	if not enhanced_focus_enabled():
		return DEFAULT_BORDER_WIDTH
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.has_node("/root/UserSettings"):
		var gameplay: Variant = tree.root.get_node("/root/UserSettings").get("gameplay")
		if gameplay != null and gameplay.has_method("focus_border_width"):
			return int(gameplay.focus_border_width())
	return ENHANCED_BORDER_WIDTH


static func focus_border_color(base: Color) -> Color:
	if not enhanced_focus_enabled():
		return base
	return Color(1.0, 0.96, 0.72, 1.0)


static func apply_button_focus_style(style: StyleBoxFlat, base_border: Color) -> void:
	style.border_color = focus_border_color(base_border)
	style.set_border_width_all(focus_border_width())
