extends SceneTree

## Six town watchmen from the census in a row, armed through CitizenGear exactly as in the
## city, each with his unit's prestige and wear cell (docs/SYSTEMS/EQUIPMENT_VARIANTS.md,
## R-2004). Picks watchmen of different posts so new (w0), used (w1) and battered (w2)
## issue all show; labels give the post and the cell. Writes the row and a close-up.
## Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_watch_variants.gd [-- --output-dir=PATH]

const OUTPUT_DIR := "res://docs/reports/images/equipment"
const COUNT := 6
const SPACING := 1.05


func _initialize() -> void:
	call_deferred("_run")


## Up to COUNT watch records, round-robin over the wear levels and one per post first.
func _pick_watchmen() -> Array[Dictionary]:
	var by_wear: Array = [[], [], []]
	var seen_posts := {}
	var roster := CitizenRoster.load_default()
	for r: Dictionary in roster.residents:
		var duty: Dictionary = r.get("duty", {})
		if String(duty.get("kit", "")) != "watch":
			continue
		var cell := String(r.get("gear_variant", "p1_w1"))
		var post := String(duty.get("post", ""))
		# Prefer one man per post; extras queue behind so the row still fills.
		var bucket: Array = by_wear[clampi(int(cell[4]), 0, 2)]
		if seen_posts.has(post):
			bucket.append(r)
		else:
			seen_posts[post] = true
			bucket.push_front(r)
	var picked: Array[Dictionary] = []
	var level := 0
	while picked.size() < COUNT and level < COUNT * 3 * 8:
		var bucket: Array = by_wear[level % 3]
		if not bucket.is_empty():
			picked.append(bucket.pop_front())
		level += 1
	return picked


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1800, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.57, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.74)
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	viewport.add_child(sun)
	var watchmen := _pick_watchmen()
	for i in watchmen.size():
		var record: Dictionary = watchmen[i].duplicate(true)
		var scene := load("res://assets/characters/variants/%s.tscn" % record["body"]) as PackedScene
		var rig := scene.instantiate() as SharedCharacterRig
		viewport.add_child(rig)
		rig.position = Vector3((i - (watchmen.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		rig.rotation_degrees = Vector3(0, 25, 0)
		CityCitizens.dye(rig, record)
		CitizenGear.arm(rig, record)
		var label := Label3D.new()
		var post := String(record["duty"].get("post", ""))
		var cell := String(record.get("gear_variant", ""))
		label.text = "%s\n%s" % [post, cell]
		label.font_size = 34
		label.pixel_size = 0.004
		label.position = Vector3(0, -0.16, 0.4)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		rig.add_child(label)
		print("WATCHMAN ", record["id"], " ", post, " ", cell, " ", record["wear"])
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.7
	camera.position = Vector3(0.0, 1.05, 7.0)
	viewport.add_child(camera)
	camera.current = true
	for _frame in 24:
		await process_frame
	var out := OUTPUT_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--output-dir="):
			out = a.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	_save(viewport, out + "/watch_variants_row.png")
	# Close-up: hats, aketons and spearheads of the whole row.
	camera.size = 1.9
	camera.position = Vector3(0.0, 1.6, 7.0)
	for _frame in 3:
		await process_frame
	_save(viewport, out + "/watch_variants_closeup.png")
	quit(0)


func _save(viewport: SubViewport, path: String) -> void:
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SAVED ", path)
