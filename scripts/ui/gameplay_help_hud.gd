class_name GameplayHelpHud
extends CanvasLayer

## Passive control hints for map scenes. Decorative labels must ignore mouse input
## so MapClickInputController can route gameplay clicks underneath.

const PANEL_MARGIN := 24.0
const HELP_TEXT := (
	"WASD or arrows - move | Click - travel | E - interact | "
	+ "Quick access or C - camera | N - map | I - inventory | J - journal"
)

var _label: Label


func _ready() -> void:
	layer = 20
	_build_ui()


func _build_ui() -> void:
	_label = Label.new()
	_label.name = "HelpLabel"
	_label.text = HELP_TEXT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_label.offset_left = -760.0
	_label.offset_top = -72.0
	_label.offset_right = -PANEL_MARGIN
	_label.offset_bottom = -PANEL_MARGIN
	_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.9, 0.92))
	_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.06, 0.05, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.add_theme_font_size_override("font_size", 14)
	add_child(_label)
