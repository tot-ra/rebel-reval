extends SceneTree

## Plates for the Hingepuu reflection screen (R-1892): a bare tree (no marks)
## and a marked tree, at 1280x720.
##   tools/godot_render.sh --script tools/capture_reflection_overlay.gd
const OUTPUT := "res://docs/reports/images/hud_menus"
const ModelScript := preload("res://scripts/reflection/reflection_model.gd")
const OverlayScene := preload("res://scenes/ui/reflection_overlay.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for kind in ["bare", "marked"]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280, 720)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var background := ColorRect.new()
		background.size = Vector2(1280, 720)
		background.color = Color("3a3f38")
		viewport.add_child(background)
		var overlay := OverlayScene.instantiate() as ReflectionOverlay
		viewport.add_child(overlay)
		overlay.present(ModelScript.build_snapshot(_make_state(kind)))
		for _frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/reflection_%s.png" % [OUTPUT, kind]
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("saved ", path)
		viewport.queue_free()
		await process_frame
	quit()


func _make_state(kind: String) -> GameState:
	var state := GameState.new()
	state.set_phase(GameState.PHASE_REFLECTION_MORNING)
	if kind == "bare":
		# Same values as the maintainer's first playthrough screenshot.
		state.adjust_pressure(GameState.PRESSURE_SUSPICION, 1)
		state.set_relationship(&"rel.henning_trust", -1)
		return state
	state.adjust_pressure(GameState.PRESSURE_SUSPICION, 2)
	state.adjust_pressure(GameState.PRESSURE_SOLIDARITY, 1)
	state.set_relationship(&"rel.henning_trust", 2)
	state.add_forged_record(
		ForgedRecord.new(
			&"record.capture",
			ModelScript.COMMISSION_WATCH_BUCKLE,
			&"item.watch_buckle",
			&"secret_feature"
		)
	)
	state.set_flag(&"flag.watch_buckle_hidden_release", true)
	return state
