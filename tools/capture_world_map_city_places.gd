extends SceneTree

## Captures the district map fast-travel tab listing the city's key places.
## tools/godot_render.sh --script tools/capture_world_map_city_places.gd

const OUTPUT := "res://docs/reports/images/world_map_city_places.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.get_node("DoorNavigator").load_manifest(true)
	# Loaded at run time: autoloads are not visible while this script compiles.
	var overlay: CanvasLayer = load("res://scripts/ui/world_map_overlay.gd").new()
	root.add_child(overlay)
	overlay.configure(&"reval_city")
	overlay.open()
	overlay.show_fast_travel()
	for _frame in 20:
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	print("capture: %s (%s)" % [OUTPUT, error])
	quit(0 if error == OK else 1)
