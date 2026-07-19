extends Node

## Sizes the main window to a fraction of the current display and matches the
## viewport base size so viewport stretch stays 1:1 on HiDPI screens.

const SCREEN_SIZE_FRACTION := 0.8
const FALLBACK_SIZE := Vector2i(1920, 1080)


static func target_window_size_for_screen(
	screen_size: Vector2i,
	fraction: float = SCREEN_SIZE_FRACTION
) -> Vector2i:
	if screen_size.x <= 0 or screen_size.y <= 0:
		return FALLBACK_SIZE
	return Vector2i(
		maxi(1, int(screen_size.x * fraction)),
		maxi(1, int(screen_size.y * fraction))
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
	# Keep render resolution aligned with the physical window size.
	window.content_scale_size = target
