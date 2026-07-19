extends Node

## Sizes the main window to a fraction of the current display. Viewport stretch
## (project.godot display/window/stretch/mode) scales the 1920x1080 design to fit.

const SCREEN_SIZE_FRACTION := 0.8
const FALLBACK_SIZE := Vector2i(1920, 1080)
const DESIGN_SIZE := Vector2i(1920, 1080)


static func target_window_size_for_screen(
	screen_size: Vector2i,
	fraction: float = SCREEN_SIZE_FRACTION
) -> Vector2i:
	if screen_size.x <= 0 or screen_size.y <= 0:
		return FALLBACK_SIZE

	var maximum_size := Vector2i(
		maxi(1, int(screen_size.x * fraction)),
		maxi(1, int(screen_size.y * fraction))
	)
	# Preserve the design aspect ratio so viewport stretching cannot distort the UI.
	var scale := minf(
		float(maximum_size.x) / float(DESIGN_SIZE.x),
		float(maximum_size.y) / float(DESIGN_SIZE.y)
	)
	return Vector2i(
		maxi(1, int(round(DESIGN_SIZE.x * scale))),
		maxi(1, int(round(DESIGN_SIZE.y * scale)))
	)


func _ready() -> void:
	apply_screen_relative_window_size()


func apply_screen_relative_window_size() -> void:
	if DisplayServer.get_name() == "headless":
		return

	var screen_index := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen_index)
	var target := target_window_size_for_screen(usable.size)

	var window := get_window()
	if window == null:
		return

	window.position = usable.position + (usable.size - target) / 2
	window.size = target
