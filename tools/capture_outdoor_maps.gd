extends SceneTree

const Coast := preload("res://scripts/map/definitions/outdoor/coast_harbor_definitions.gd")
const Villages := preload("res://scripts/map/definitions/outdoor/village_monastery_definitions.gd")
const Castles := preload("res://scripts/map/definitions/outdoor/castle_definitions.gd")
const Wilderness := preload("res://scripts/map/definitions/outdoor/wilderness_event_definitions.gd")
const Renderer := preload("res://scripts/map/definitions/outdoor/outdoor_prototype_renderer.gd")

const OUTPUT_DIR := "res://docs/reports/images/outdoor"
const VIEWPORT_SIZE := Vector2i(1600, 900)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for definition in _all():
		var viewport := SubViewport.new()
		viewport.size = VIEWPORT_SIZE
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewport.transparent_bg = false
		root.add_child(viewport)

		var renderer := Renderer.new()
		renderer.configure(definition, MapBuilder.build(definition))
		var scale := minf(1500.0 / definition.world_size().x, 800.0 / definition.world_size().y)
		renderer.scale = Vector2.ONE * scale
		renderer.position = Vector2(50, 55)
		viewport.add_child(renderer)

		await process_frame
		await process_frame
		var image := viewport.get_texture().get_image()
		var output := "%s/%s.png" % [OUTPUT_DIR, String(definition.map_id).replace("prototype.", "")]
		var error := image.save_png(ProjectSettings.globalize_path(output))
		if error != OK:
			push_error("Could not save outdoor capture %s: %s" % [output, error_string(error)])
			quit(1)
			return
		print("Outdoor capture: %s" % output)
		viewport.queue_free()
		await process_frame
	quit(0)


func _all() -> Array[MapDefinition]:
	var definitions: Array[MapDefinition] = []
	definitions.append_array(Coast.all())
	definitions.append_array(Villages.all())
	definitions.append_array(Castles.all())
	definitions.append_array(Wilderness.all())
	return definitions
