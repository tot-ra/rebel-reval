extends SceneTree

## Captures the Reval fast-travel map: idle with a "you are here" marker, a hovered
## place caption, and the traveler mid-walk.
## tools/godot_render.sh --script tools/capture_reval_map.gd
const OUT_DIR := "res://docs/reports/images/"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 1000)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	# Loaded at runtime: autoloads (DoorNavigator) do not exist when a --script file compiles.
	var overlay: Node = load("res://scripts/ui/world_map_overlay.gd").new()
	viewport.add_child(overlay)
	overlay.configure(&"reval_city")
	overlay.open()
	overlay.show_fast_travel()
	var view: Control = overlay.get("_fast_travel_view")
	view.configure_city(&"reval_city", overlay.get("_travelable"), &"city_forum")
	await _frames(10)
	_save(viewport, "reval_map_idle.png")
	view._show_caption(&"city_kalev_smithy")
	await _frames(5)
	_save(viewport, "reval_map_caption.png")
	view._hide_caption(&"city_kalev_smithy")
	view._begin_travel(&"city_viru_outside")
	await _frames(45)
	_save(viewport, "reval_map_walking.png")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(viewport: SubViewport, file_name: String) -> void:
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT_DIR + file_name))
