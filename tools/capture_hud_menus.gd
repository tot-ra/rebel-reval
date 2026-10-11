extends SceneTree

## Render real UI nodes on a neutral review stage, not a simulated playthrough.
## tools/godot_render.sh --script tools/capture_hud_menus.gd
## --before is only for the pre-redesign revision, not a reconstructed baseline.
const OUTPUT := "res://docs/reports/images/hud_menus"
const Settings := preload("res://scripts/ui/game_settings_overlay.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var before := "--before" in OS.get_cmdline_user_args()
	var suffix := "before" if before else "after"
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var background := ColorRect.new()
		background.size = dimensions
		background.color = Color("252b2b")
		viewport.add_child(background)
		var note := Label.new()
		note.position = Vector2(32, 24)
		note.text = "REVAL REBEL  /  UI REVIEW STAGE (not a gameplay capture)"
		note.add_theme_color_override("font_color", Color("aa9980"))
		viewport.add_child(note)
		var minimap := CityMinimap.create(CityPlan.load_default())
		viewport.add_child(minimap)
		minimap.update_view(Vector2.ZERO, Vector2.UP, 0.0, -1)
		if before:
			var ring := CharacterHealthRing.new()
			ring.position = Vector2(dimensions) * 0.5
			ring.set_health(72, 100)
			viewport.add_child(ring)
		else:
			var vitals_script: Script = load("res://scripts/ui/player_vitals_hud.gd")
			var vitals: CanvasLayer = vitals_script.new()
			viewport.add_child(vitals)
			vitals.set_process(false)
			vitals.call("set_vitals", 72.0, 100.0, 46.0, 100.0)
		await _save(viewport, "vitals_%s_%d" % [suffix, dimensions.x])
		var settings := Settings.new()
		viewport.add_child(settings)
		settings.open()
		await _save(viewport, "escape_%s_%d" % [suffix, dimensions.x])
		viewport.queue_free()
		await process_frame
	quit()


func _save(viewport: SubViewport, filename: String) -> void:
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var error := image.save_png("%s/%s.png" % [OUTPUT, filename])
	if error != OK:
		push_error("UI capture failed: %s" % filename)
		quit(1)
	print("UI_CAPTURE ", filename, " ", image.get_size())
