extends SceneTree

## ADR 0061 (R-2184): the hero exposure HUD stages on the neutral UI review stage, next to the
## real vitals block. Not a gameplay capture.
## tools/godot_render.sh --script tools/capture_exposure_hud.gd
const OUTPUT := "res://docs/reports/images/hero_exposure"
const StatusHud := preload("res://scripts/ui/exposure_status_hud.gd")
## [file, wetness, body heat, health]
const STAGES := [
	["damp_chilled", 0.3, 0.6, 100.0],
	["soaked_freezing", 0.9, 0.2, 100.0],
	["freezing_to_death", 1.0, 0.0, 38.0],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for stage: Array in STAGES:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280, 720)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var background := ColorRect.new()
		background.size = Vector2(1280, 720)
		background.color = Color("3a4148")
		viewport.add_child(background)
		var note := Label.new()
		note.position = Vector2(32, 24)
		note.text = "REVAL REBEL  /  UI REVIEW STAGE  /  exposure: %s" % stage[0]
		note.add_theme_color_override("font_color", Color("aa9980"))
		viewport.add_child(note)
		var vitals: CanvasLayer = load("res://scripts/ui/player_vitals_hud.gd").new()
		viewport.add_child(vitals)
		vitals.set_process(false)
		vitals.call("set_vitals", float(stage[3]), 100.0, 0.0, 100.0)
		var hud: CanvasLayer = StatusHud.new()
		hud.follow_settings = false
		hud.reduced_motion = true
		viewport.add_child(hud)
		await process_frame
		# Straight to the stage: the cold line is said last, so it is the one on screen.
		hud.call("show_exposure", float(stage[1]), float(stage[2]))
		await _save(viewport, "exposure_hud_%s" % stage[0])
		viewport.queue_free()
		await process_frame
	quit()


func _save(viewport: SubViewport, filename: String) -> void:
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT, filename]
	if image.save_png(path) != OK:
		push_error("exposure capture failed: %s" % filename)
		quit(1)
	print("plate: ", path)
