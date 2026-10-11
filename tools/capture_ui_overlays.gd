extends SceneTree

## Before/after plates for the overlays that share the Escape-menu skin (R-1800):
## journal, inventory, spellforge cookbook and controls, at 1280x720 and 1920x1080.
##   tools/godot_render.sh --script tools/capture_ui_overlays.gd -- --tag=before|after
## The tag only names the files; run "before" on the revision before the change.
## The journal shows no deadlines here: CommissionDeadlineModel names the
## SessionState autoload, which a SceneTree --script entry cannot compile.
const OUTPUT := "res://docs/reports/images/hud_menus"
const CONTENT_DIRS: Array[String] = ["res://content/examples/valid", "res://content/demo"]
const SPELL_DIRS: Array[String] = ["res://content/examples/valid", "res://content/examples/support"]
const JournalScript := preload("res://scripts/journal/journal_overlay.gd")
const InventoryScript := preload("res://scripts/inventory/inventory_overlay.gd")
const SpellforgeScript := preload("res://scripts/magic/spellforge_hud.gd")
const SpellforgeModelScript := preload("res://scripts/magic/spellforge_model.gd")
const ControlsScript := preload("res://scripts/ui/controls_overlay.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var tag := "after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for kind in ["journal", "inventory", "spellforge", "controls"]:
			var viewport := SubViewport.new()
			viewport.size = dimensions
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var background := ColorRect.new()
			background.size = dimensions
			background.color = Color("252b2b")
			viewport.add_child(background)
			viewport.add_child(_make_overlay(kind, viewport))
			await _save(viewport, "%s_%s_%d" % [kind, tag, dimensions.x])
			viewport.queue_free()
			await process_frame
	quit()


func _make_overlay(kind: String, viewport: SubViewport) -> CanvasLayer:
	var state := GameState.new()
	var db := ContentDB.new()
	match kind:
		"journal":
			db.load_from_directories(CONTENT_DIRS)
			var journal: CanvasLayer = JournalScript.new()
			journal.configure(state, db)
			journal.ready.connect(journal.open)
			return journal
		"inventory":
			db.load_from_directories(CONTENT_DIRS)
			var bag := InventoryBag.new()
			bag.set_content_db(db)
			bag.try_add(&"item.seized_spearhead")
			var inventory: CanvasLayer = InventoryScript.new()
			inventory.ready.connect(func() -> void:
				inventory.configure(bag, db)
				inventory.configure_state(state)
				inventory.open())
			return inventory
		"spellforge":
			db.load_from_directories(SPELL_DIRS)
			MagicResolver.apply_grant_operation(state, db, &"magic.grant.starter_fireball")
			MagicResolver.apply_grant_operation(state, db, &"magic.grant.starter_earth_tremor")
			var model := SpellforgeModelScript.new() as SpellforgeModel
			model.configure(state, db)
			var hud: CanvasLayer = SpellforgeScript.new()
			hud.configure(model)
			hud.ready.connect(hud.open)
			return hud
		_:
			var controls: CanvasLayer = ControlsScript.new()
			controls.configure(viewport.get_node("/root/UserSettings"))
			controls.ready.connect(controls.open)
			return controls


func _save(viewport: SubViewport, filename: String) -> void:
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var error := image.save_png("%s/%s.png" % [OUTPUT, filename])
	if error != OK:
		push_error("UI overlay capture failed: %s" % filename)
		quit(1)
	print("UI_OVERLAY_CAPTURE ", filename, " ", image.get_size())
